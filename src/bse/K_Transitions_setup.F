!
!        Copyright (C) 2000-2020 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM, DS
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine K_Transitions_setup(iq,Ken,Xk,Dip)
 !
 ! Filling of Transition groups
 !
 !type BS_T_group
 !  integer                       :: ik         ! ik index (\in IBZ)
 !  integer                       :: first_cv   ! Position in the cv transitions @ k
 !  integer                       :: size       
 !  complex(SP), allocatable      :: table(size,5,R/A) ; 5 --> (/ikbz,iv,ic,i_sp_c,i_sp_v/)
 !  complex(SP), allocatable      :: Z(size,R/A)
 !  real(SP)   , allocatable      :: E(size,R/A)
 !  real(SP)   , allocatable      :: f(size,R/A)
 !  real(SP)   , allocatable      :: W(size,R/A)
 !end type BS_T_group
 !
 use pars,         ONLY:SP
 use stderr,       ONLY:intc
 use com,          ONLY:isec
 use BS_solvers,   ONLY:BSS_mode
 use BS,           ONLY:T_group,BS_bands,BS_T_grp,BS_nT_grps,BS_res_ares_dim,&
&                       BS_Blocks_and_Transitions_alloc,BS_perturbative_SOC
 use DIPOLES,      ONLY:DIPOLE_t
 use parallel_m,   ONLY:PAR_IND_WF_b_and_k,PAR_IND_T_ordered,PAR_IND_T_groups,&
&                       PAR_IND_T_Haydock,PP_indexes_reset
 use electrons,    ONLY:levels,n_sp_pol
 use com,          ONLY:msg
 use R_lattice,    ONLY:qindx_X,bz_samp
 use BS,           ONLY:l_BS_magnons,l_BS_photolum
 !
#if defined _RT
 use parser_m,     ONLY:parser
#endif
 !
#include<memory.h>
 !
 type(levels)   :: Ken
 type(bz_samp)  :: Xk
 type(DIPOLE_t) :: Dip
 integer        :: iq
 !
 logical, external :: T_is_ok
 !
 ! Work Space
 !
 character(1) :: sec
 real(SP)     :: E_eh,E_eh_SOC_corr(2/n_sp_pol),f_eh,f_eh_RES,f_eh_PL
 logical      :: l_trans_in_group,l_grp_to_grp,FORCE_EQ_trans
 integer      :: ikbz,ikpbz,iv,ic,ik,ikp,i_sp_v,i_sp_c,i_star,nb(2),ib1,ib2,isp1,isp2,  &
 &               i_T_now,i_T_group_now,i_T_group_last,i_T_group_start,i_g,n_loops,i_loop,i_T_in_the_grp,i_res_ares
 !
 FORCE_EQ_trans=.true.
 !
#if defined _RT
 call parser('ForceEqTrans',FORCE_EQ_trans)
#endif
 !
 if (isec(3)/=0) sec="-"
 if (isec(3)==0) sec="+"
 !
 call section(sec,'Transition Groups build-up @q'//trim(intc(iq)))
 !
 call k_build_up_BZ_tables(Xk)
 !
 ! BS_nT_grps is first computed in PARALLEL_Transition_grouping
 !
 allocate(BS_T_grp(BS_nT_grps))
 do i_g=1,BS_nT_grps
   BS_T_grp(i_g)%size=0
 enddo
 n_loops=2
 !
 call PP_indexes_reset(PAR_IND_WF_b_and_k)
 YAMBO_ALLOC(PAR_IND_WF_b_and_k%element_2D,(BS_bands(2),Xk%nibz))
 PAR_IND_WF_b_and_k%element_2D=.FALSE.
 !
 nb(1)=Ken%nbf+1
 nb(2)=Ken%nbm
!#if defined _RT
! if(all(Ken%nbc/=0)) nb=Ken%nbc
!#endif
 !
 do i_loop=1,n_loops
   !
   i_T_now=0
   i_T_group_now=0
   i_T_group_last=0
   !
   ! DS: WARNING
   ! I cannot revert ik and i_sp_pol loop here ...
   !
   do i_res_ares=1,BS_res_ares_dim
     !
     i_T_group_start=i_T_group_now+1
     !
     do ik=1,Xk%nibz
       !
       ! Here I cannot invert the ik and the i_sp loop since 
       ! BS_T_grp and BS_nT_at_k are defined according to kpts while they
       ! should be defined according to both i_sp_pol and kpts
       !
       ! Moreover I cannot move iv,ic loops insiede i_sp_pol and i_star loops
       ! Otherwise runs with parallelization over eh fail
       !
       do iv=BS_bands(1),nb(2)
         do ic=nb(1),BS_bands(2)
           !
           do i_sp_c=1,n_sp_pol
             i_sp_v=i_sp_c
             !
             if (l_BS_magnons.and.n_sp_pol==2) then
               if(i_res_ares==1.and.i_sp_c==1) cycle
               if(i_res_ares==2.and.i_sp_c==2) cycle
               i_sp_v=mod(i_sp_c,n_sp_pol)+1
             endif
             !
             do i_star=1,Xk%nstar(ik)
               !
               ikbz=Xk%k_table(ik,Xk%star(ik,i_star))
               !
               ikpbz=qindx_X(iq,ikbz,1)
               ikp  =Xk%sstar(ikpbz,1)
               !
               if(i_res_ares==1) then; ib1=iv; ib2=ic; isp1=i_sp_v; isp2=i_sp_c; endif
               if(i_res_ares==2) then; ib1=ic; ib2=iv; isp1=i_sp_c; isp2=i_sp_v; endif
               !
               if (.not.T_is_ok(Ken,Dip,iq,ik,ikp,ib1,ib2,isp2,i_res_ares,&
               &                FORCE_EQ_trans,E_eh,E_eh_SOC_corr,f_eh,f_eh_RES,f_eh_PL)) cycle
               !
               i_T_now=i_T_now+1
               i_T_group_now=T_group(i_T_now)
               !
               if (i_loop==1) BS_T_grp(i_T_group_now)%size=BS_T_grp(i_T_group_now)%size+1
               !
               l_trans_in_group=PAR_IND_T_groups%element_1D(i_T_group_now)
               !
               l_grp_to_grp= any( PAR_IND_T_ordered%element_2D(i_T_group_now,:)) .or. &
  &                          any( PAR_IND_T_ordered%element_2D(:,i_T_group_now))
               !
               if ( .not. (l_trans_in_group .or. l_grp_to_grp) ) cycle
               !
               if (i_T_group_now/=i_T_group_last) then
                 !
                 i_T_group_last=i_T_group_now
                 i_T_in_the_grp=0
                 !
                 if (i_loop==2) then
                   !
                   call BS_Blocks_and_Transitions_alloc(Ken,i_T_group_now)
                   !
                   BS_T_grp(i_T_group_now)%i_T_ref   =i_T_group_start 
                   BS_T_grp(i_T_group_now)%i_res_ares=i_res_ares
                   BS_T_grp(i_T_group_now)%ik        =ik
                   BS_T_grp(i_T_group_now)%first_cv  =i_T_now
                   !
                 endif
                 !
               endif
               !
               if (i_loop==1) cycle
               !
               i_T_in_the_grp=i_T_in_the_grp+1
               !
               BS_T_grp(i_T_group_now)%table(i_T_in_the_grp,:)=(/ikbz,ib1,ib2,isp2,isp1/)
               !
               PAR_IND_WF_b_and_k%element_2D(ic,ik )=.TRUE.
               PAR_IND_WF_b_and_k%element_2D(iv,ikp)=.TRUE.
               !
               if ((index(BSS_mode,'h')/=0) .or. (index(BSS_mode,'s')/=0)) then
                  PAR_IND_T_Haydock%element_1D(i_T_group_now)=.TRUE.
               endif
               !
               BS_T_grp(i_T_group_now)%E(i_T_in_the_grp) =E_eh
               BS_T_grp(i_T_group_now)%f(i_T_in_the_grp) =f_eh
               !
               ! To be fixed
               if (l_BS_photolum) BS_T_grp(i_T_group_now)%f_PL(i_T_in_the_grp,1) =f_eh_PL
               !
               BS_T_grp(i_T_group_now)%f_RES(i_T_in_the_grp)=f_eh_RES
               !
               if (allocated(Ken%Z)) BS_T_grp(i_T_group_now)%Z(i_T_in_the_grp)=&
               &                                           Ken%Z(ic,ik,i_sp_c)*Ken%Z(iv,ikp,i_sp_v)
               !
               ! Note that W is negative as the linewidth is negative(positive) above(below) the Fermi level.
               ! Presently there is the abs value here and a minus in K_IP.F
               !
               if (allocated(Ken%W)) BS_T_grp(i_T_group_now)%W(i_T_in_the_grp)= &
               &                        (-1._SP)**(i_res_ares-1)*(abs(Ken%W(ic,ik,i_sp_c))+abs(Ken%W(iv,ikp,i_sp_c)))
               !
               if ( BS_perturbative_SOC ) BS_T_grp(i_T_group_now)%E_SOC_corr(:,i_T_in_the_grp)=E_eh_SOC_corr(:)
               !
             enddo ! conduction 
           enddo ! valence
           !
         enddo ! symmetries
       enddo ! spin 
     enddo ! k (ibz)
     !
   enddo ! i_res_ares
   !
 enddo ! loop
 !
 ! REPORT
 !
 call msg('r','[BSK] Transition groups (total)',BS_nT_grps)
 !
end subroutine
!
!
subroutine K_compute_transitions_at_ik(iq,Ken,Xk,Dip)
 !
 ! Out: 
 !
 !   BS_K_dim(1)
 !   BS_H_dim
 !   BS_nT_at_k
 !
 use pars,         ONLY:SP
 use R_lattice,    ONLY:qindx_X,bz_samp
 use electrons,    ONLY:levels,n_sp_pol
 use DIPOLES,      ONLY:DIPOLE_t
 use BS_solvers,   ONLY:BSS_add_antiresonant,BSS_mode,BSS_slepc_double_grp,BSS_slepc_matrix
 use BS,           ONLY:BS_K_dim,BS_H_dim,BS_nT_at_k,BSE_mode,    &
&                       BS_K_coupling,BS_bands,BS_not_const_eh_f,BS_K_coupling,  &
&                       l_BS_ares_asymm,BS_res_ares_dim,BS_mat_res_ares_dim
 use parser_m,     ONLY:parser
 use BS,           ONLY:l_BS_magnons,l_BS_photolum
 !
#include<memory.h>
 !
 type(levels)   :: Ken
 type(bz_samp)  :: Xk
 type(DIPOLE_t) :: Dip
 integer        :: iq
 !
 logical, external :: T_is_ok
 !
 ! Work Space
 !
 real(SP)     :: E_eh,E_eh_SOC_corr(2/n_sp_pol),f_eh,f_eh_RES,f_eh_PL
 logical      :: FORCE_EQ_trans,l_BS_ares_symm,l_slepc_special
 integer      :: ikbz,ikpbz,iv,ic,ik,ikp,i_sp_v,i_sp_c,ib1,ib2,isp1,&
 &               i_star,nb(2),BS_nT_at_k_tmp(Xk%nibz*2),i_res_ares
 !
 FORCE_EQ_trans=.true.
 !
#if defined _RT
 call parser('ForceEqTrans',FORCE_EQ_trans)
#endif
 !
 ! Here we will have two options to initialize the slepc matrix:
 call parser('BSSSlepcMatrix',BSS_slepc_matrix)
 !
 ! Developer options. Without the code works in default mode
 ! With the user can switch to experimental coding
 call parser('ImposeAsym',l_BS_ares_asymm)
 call parser('ImposeSymm',l_BS_ares_symm)
 !
 l_BS_ares_asymm=l_BS_ares_asymm.or.(iq/=1)
 l_BS_ares_asymm=(l_BS_ares_asymm.or.l_BS_photolum.or.(l_BS_magnons.and.n_sp_pol==2))
 !
#if defined _SLEPC && !defined _SLEPC_OFF
 ! Special case, slepc with distributed matrix need to explicitly compute the anti-resonant block
 l_slepc_special = index(BSS_mode,'s')/=0 .and. BS_K_coupling .and. (.not.BSS_slepc_matrix)
 ! The doubling is activated unless explicily imposed by input since slepc
 ! with shells requires the extended K_multiply_by_V for the non hermitian algorithm
 ! Slepc are not (yet) able to deal with a pseudo-hermitian algorithm 
 l_BS_ares_asymm=l_BS_ares_asymm .or. (l_slepc_special.and..not.l_BS_ares_symm)
 BSS_slepc_double_grp=(.not.l_BS_ares_asymm).and.l_slepc_special
#endif
 !
 l_BS_ares_asymm=l_BS_ares_asymm.and.trim(BSE_mode)/="resonant"
 !
 BS_res_ares_dim=1
 BS_mat_res_ares_dim=1
 if (l_BS_ares_asymm) then
   BS_res_ares_dim=2
   if (.not.BS_K_coupling) BS_mat_res_ares_dim=2
 endif
 !
 BS_K_dim=0
 BS_nT_at_k_tmp=0
 !
 call k_build_up_BZ_tables(Xk)
 !
 nb(1)=Ken%nbf+1
 nb(2)=Ken%nbm
!#if defined _RT
! if(all(Ken%nbc/=0)) nb=Ken%nbc
!#endif
 !
 do i_res_ares=1,BS_res_ares_dim
   do i_sp_c=1,n_sp_pol
     i_sp_v=i_sp_c
     !
     if (l_BS_magnons.and.n_sp_pol==2) then
       if(i_res_ares==1.and.i_sp_c==1) cycle
       if(i_res_ares==2.and.i_sp_c==2) cycle
       i_sp_v=mod(i_sp_c,n_sp_pol)+1
     endif
     !
     do ik=1,Xk%nibz
       do i_star=1,Xk%nstar(ik)
         !
         ikbz=Xk%k_table(ik,Xk%star(ik,i_star))
         ikpbz=qindx_X(iq,ikbz,1)
         ikp  =Xk%sstar(ikpbz,1)
         !
         do iv=BS_bands(1),nb(2)
           do ic=nb(1),BS_bands(2)
             !
             if(i_res_ares==1) then; ib1=iv; ib2=ic; isp1=i_sp_c ; endif
             if(i_res_ares==2) then; ib1=ic; ib2=iv; isp1=i_sp_v ; endif
             !
             if (.not.T_is_ok(Ken,Dip,iq,ik,ikp,ib1,ib2,isp1,i_res_ares,&
             &                FORCE_EQ_trans,E_eh,E_eh_SOC_corr,f_eh,f_eh_RES,f_eh_PL)) cycle
             !
             BS_K_dim(i_res_ares)=BS_K_dim(i_res_ares)+1
             !
             BS_nT_at_k_tmp(ik+(i_res_ares-1)*Xk%nibz)=BS_nT_at_k_tmp(ik+(i_res_ares-1)*Xk%nibz)+1
             !
           enddo ! conduction 
         enddo ! valence
         !
       enddo ! symmetries
     enddo ! k (ibz) 
   enddo ! spin
 enddo ! i_res_ares
 !
 if (.not.BSS_add_antiresonant.and.BS_not_const_eh_f.and..not.BS_K_coupling) then
   call warning('Fractional e/h occupations but resonant only mode selected in input.')
   !! This is not neeeded since now occupations are used in the form (f_v-f_c)
   !! It waas needed with the old version f_v(1-f_c)
   !BSE_mode='retarded'
   !BSS_add_antiresonant=.true.
 endif
 !
 YAMBO_ALLOC(BS_nT_at_k,(Xk%nibz*BS_res_ares_dim))
 BS_nT_at_k=BS_nT_at_k_tmp(:Xk%nibz*BS_res_ares_dim)
 !
 if (any(BS_nT_at_k==0)) call warning(' Null BSE kernel block dimension(s) found.')
 if (sum(BS_nT_at_k)==0) call   error(' The whole BSE has zero dimension !')
 !
 BS_H_dim=BS_K_dim(1)
 if (l_BS_ares_asymm) then
   if (BS_mat_res_ares_dim==2.or.BS_K_coupling) BS_H_dim=BS_K_dim(1)+BS_K_dim(2)
 else
   if (BS_K_coupling) BS_H_dim=2*BS_K_dim(1)
 endif
 !
end subroutine
!
!
logical function T_is_ok(Ken,Dip,iq,ik,ikp,iv,ic,i_sp_c,i_res_ares,FORCE_EQ_trans,E_eh,E_eh_SOC_corr,f_eh,f_eh_RES,f_eh_PL)
 !
 use pars,         ONLY:SP 
 use X_m,          ONLY:global_gauge
 use DIPOLES,      ONLY:DIPOLE_t
 use electrons,    ONLY:levels,n_sp_pol,filled_tresh,spin_occ
 use BS,           ONLY:BS_not_const_eh_f,BS_perturbative_SOC,BS_eh_en,l_BS_magnons
#if defined _RT
 use drivers,      ONLY:l_rt_carriers_in_use
 use RT_control,   ONLY:NEQ_Residuals,NEQ_Kernel
#endif
 !
 implicit none
 !
 type(levels),   intent(in) :: Ken
 type(DIPOLE_t), intent(in) :: Dip
 integer,        intent(in) :: iq,ik,ikp,iv,ic,i_sp_c,i_res_ares
 logical,        intent(in) :: FORCE_EQ_trans
 real(SP),       intent(out):: E_eh,E_eh_SOC_corr(2/n_sp_pol),f_eh,f_eh_RES,f_eh_PL
 !
 ! Work Space
 !
 integer :: i_sp_v,iv_SOC(2/n_sp_pol),ic_SOC(2/n_sp_pol),pert_range(2/n_sp_pol,2)
 real(SP):: Eo_eh,E_v_SOC(2/n_sp_pol),E_c_SOC(2/n_sp_pol),f_eh_REF,f_e,f_h,f_check
 !
 T_is_ok=.TRUE.
 !
 i_sp_v=i_sp_c
 if(l_BS_magnons) i_sp_v=mod(i_sp_c,n_sp_pol)+1
 !
 E_eh= Ken%E(ic,ik ,i_sp_c)-Ken%E(iv,ikp,i_sp_v)
 if (     allocated(Ken%Eo)) Eo_eh= Ken%Eo(ic,ik ,i_sp_c)-Ken%Eo(iv,ikp,i_sp_v)
 if (.not.allocated(Ken%Eo)) Eo_eh= E_eh
 !
 ! Small energy transitions. Dipoles in length gauge are not defined
 if ( abs(Eo_eh) < Dip%Energy_treshold .and. trim(global_gauge)=="length" .and. iq==1 .and..not.l_BS_magnons) T_is_ok=.FALSE.
 !
 if( BS_perturbative_SOC ) then
   if(n_sp_pol==1) pert_range=reshape((/1,2,1,2/),(/2,2/))
   if(n_sp_pol==2) pert_range=reshape((/i_sp_c,1 /),(/1,2/))
   iv_SOC(pert_range(:,2))=Ken%table_SOC(pert_range(:,1),iv,ikp)
   ic_SOC(pert_range(:,2))=Ken%table_SOC(pert_range(:,1),ic,ik )
   if(     all(iv_SOC/=0)) E_v_SOC(:)=Ken%E_SOC(iv_SOC(:),ikp)
   if(     all(ic_SOC/=0)) E_c_SOC(:)=Ken%E_SOC(ic_SOC(:),ik )
   if(.not.all(iv_SOC/=0)) E_v_SOC(:)=Ken%E(iv,ikp,i_sp_v)
   if(.not.all(ic_SOC/=0)) E_c_SOC(:)=Ken%E(ic,ik ,i_sp_c)
   E_eh_SOC_corr(:)=E_c_SOC(:)-E_v_SOC(:)-Eo_eh
 endif
 !
 ! Occupations Factors
 !=====================
 !
 f_eh_REF =(Ken%f(iv,ikp,i_sp_v)-Ken%f(ic,ik ,i_sp_c))/spin_occ
 f_eh     =f_eh_REF
 f_eh_RES =f_eh_REF
 f_check  =f_eh_REF
 !
 ! f_eh  enter the excitonic Hamiltonian
 ! f_eh_RES enter the residual of the dielectric constant
 !
#if defined _RT
 if (l_rt_carriers_in_use.and.allocated(Ken%fo)) then
   if (     FORCE_EQ_trans) f_eh_REF=(Ken%fo(iv,ikp,i_sp_v)-Ken%fo(ic,ik ,i_sp_c))/spin_occ
   if (.not.FORCE_EQ_trans) f_eh_REF=(Ken%f (iv,ikp,i_sp_v)-Ken%f (ic,ik ,i_sp_c))/spin_occ
   if (     NEQ_Kernel    ) f_eh =(Ken%f (iv,ikp,i_sp_v)-Ken%f (ic,ik ,i_sp_c))/spin_occ
   if (.not.NEQ_Kernel    ) f_eh =(Ken%fo(iv,ikp,i_sp_v)-Ken%fo(ic,ik ,i_sp_c))/spin_occ
   if (     NEQ_Residuals ) f_eh_RES=(Ken%f (iv,ikp,i_sp_v)-Ken%f (ic,ik ,i_sp_c))/spin_occ
   if (.not.NEQ_Residuals ) f_eh_RES=(Ken%fo(iv,ikp,i_sp_v)-Ken%fo(ic,ik ,i_sp_c))/spin_occ
 endif
#endif
 !
 if(i_res_ares==1) then
   f_e = (         Ken%f(iv,ikp,i_sp_v))/spin_occ
   f_h = (spin_occ-Ken%f(ic,ik ,i_sp_c))/spin_occ
 else
   f_e = (         Ken%f(ic,ikp,i_sp_c))/spin_occ
   f_h = (spin_occ-Ken%f(iv,ik ,i_sp_v))/spin_occ
 endif
 !
 f_eh_PL = Ken%f(ic,ikp,i_sp_c)*(spin_occ-Ken%f(iv,ik ,i_sp_v))/spin_occ/spin_occ
 !
 ! A 0.001 % fractional occupation swiches on the particular treatment of finite temp. BSE 
 if ( abs(abs(f_eh_REF)-1._SP)> filled_tresh ) BS_not_const_eh_f=.TRUE.
 !
 ! f_eh<0 transitions are included in the anti-resonant part
 ! f_eh=0 transitions give no contribution to absorption and are not considered
 if ( f_eh_REF*(-1._SP)**(i_res_ares-1)<0._SP ) T_is_ok=.FALSE.
 !
#if defined _RT
 !
 ! In case of population inversion, it may be problematic if f_eh>0. and f_eh_RES<0.
 if ( f_eh_REF*f_eh<0._SP .or. f_eh_REF*f_eh_RES<0._SP ) &
&      call error(' I cannot split the R and K BSE contribution.'//&
&                 ' ACTION: Use the same occupations in K and R.')
 !
#endif
 !
#if defined _RT
 if (.not.l_rt_carriers_in_use) then
#endif
   !
   ! If I've included in valence states that are almost empty
   ! or in conduction states that are almost full, those are neglected
   if ( (f_e<=filled_tresh) .or. (f_h<=filled_tresh) ) T_is_ok=.FALSE.
   !
#if defined _RT
 endif
#endif
 !
 if (any((/abs(E_eh)<BS_eh_en(1).and.BS_eh_en(1)>0._SP,&
&              abs(E_eh)>BS_eh_en(2).and.BS_eh_en(2)>0._SP/))) T_is_ok=.FALSE.
 !
end function
