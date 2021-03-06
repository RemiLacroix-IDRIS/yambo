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
subroutine Dipole_transverse(Xen,Xk,Dip)
 !
 ! This routine returns <iR> and <P^2>.
 !
 use pars,                ONLY:SP,schlen,cZERO
 use drivers,             ONLY:l_sc_run,l_nl_optics
 use interfaces,          ONLY:WF_load,WF_free
 use LIVE_t,              ONLY:live_timing
 use electrons,           ONLY:levels,n_spinor,n_sp_pol,spin_string
 use parallel_m,          ONLY:PAR_IND_DIPk_ibz,PAR_DIPk_ibz_index,PAR_IND_DIPk_ibz_ID,&
&                              PAR_IND_VAL_BANDS_DIP,PAR_IND_VAL_BANDS_DIP_ID,&
&                              PAR_IND_CON_BANDS_DIP,PAR_IND_CON_BANDS_DIP_ID
 use pseudo,              ONLY:PP_free,pp_table,Vnl,pp_n_l_comp,pp_kbv_dim_yambo,pp_kbv_table,pp_factor
 use R_lattice,           ONLY:bz_samp
 use R_lattice,           ONLY:g_vec_d,g_vec
 use DIPOLES,             ONLY:DIPOLE_t,DIP_iR,P_square,DIP_P,DIP_v,DIP_P_spinor,use_g_space_approach,&
&                              compute_P2_dipoles,compute_Spin_dipoles
 use X_m,                 ONLY:l_X_terminator
 use IO_m,                ONLY:io_control,manage_action,RD_CL_IF_END,OP_RD
 use wave_func,           ONLY:wf_ng,WF
 use com,                 ONLY:msg
 use timing_m,            ONLY:timing
 use cuda_m,              ONLY:have_cuda
 use deviceXlib_m,        ONLY:dev_memcpy
 !
#include<dev_defs.h>
#include<memory.h>
 !
 type(bz_samp), intent(in)    :: Xk
 type(levels),  intent(in)    :: Xen
 type(DIPOLE_t),intent(inout) :: Dip
 !
 ! Work Space
 !
 character(schlen)            :: live_t_string
 logical                      :: l_eval_DIP_iR,l_eval_DIP_V,l_eval_DIP_P2,l_use_comm
 integer                      :: ik,ic_wf,iv_wf,ic,iv,ifrag,&
&                                i_sp_pol,n_LT_steps,ik_mem,ic_min
 complex(SP), allocatable     :: kbv(:,:,:,:)
 complex(SP), allocatable DEV_ATTR :: kbv_d(:,:,:,:)
 complex(SP)                  :: rho_spinor(3,n_spinor,n_spinor),rho(3),P2
 real(SP)                     :: Ev_m_Ev_KS,Dipole_Energy_treshold
 !
 !I/O and external functions
 !
 integer                      :: ID,IO_ACT_NOW,io_err(3),io_KB_abinit_err,io_KB_pwscf_err,io_Vnl_err
 integer, external            :: io_KB_abinit,io_KB_pwscf,io_Vnl
 !
 call timing('DIPOLE_transverse',OPR='start')
 !
 ! Logicals setup
 !================
 !
 l_eval_DIP_iR=use_g_space_approach
 l_eval_DIP_V =use_g_space_approach.or.Dip%force_v_g_space
 l_eval_DIP_P2=compute_P2_dipoles
 !
 ! Synchronize some memory
 if (have_cuda) then
   YAMBO_ALLOC_SOURCE(g_vec_d,g_vec)
 endif
 !
 l_use_comm=l_eval_dip_V.or.l_eval_dip_iR
 !
 if(l_use_comm) then
   !
   call DIPOLE_kb_init(Xen,Dip,io_err,ID)
   !
   io_KB_abinit_err= io_err(1)
   io_KB_pwscf_err = io_err(2)
   io_Vnl_err      = io_err(3)
   !
   ! Define pp_kbv_dim_yambo and pp_kbv_table
   !
   if (io_KB_pwscf_err==0) then
     call io_control(ACTION=OP_RD,SEC=(/2/),ID=ID)
     io_KB_pwscf_err=io_KB_pwscf(ID)
     call DIPOLE_kb_pwscf_def_dim()
   endif
   !
   if (io_KB_abinit_err==0) then
     call io_control(ACTION=OP_RD,SEC=(/2/),ID=ID)
     io_KB_abinit_err=io_KB_abinit(ID)
     call DIPOLE_kb_abinit_def_dim()
   endif
   !
   if(io_KB_abinit_err==0.or.io_KB_pwscf_err==0) then
     YAMBO_ALLOC(kbv,(wf_ng,n_spinor,4,pp_kbv_dim_yambo))
     ! allocation of DEV variabless with zero dims is a problem (PGI, CUDA For)
     if (have_cuda) then
       YAMBO_ALLOC(kbv_d,(wf_ng,n_spinor,4,max(pp_kbv_dim_yambo,1)))
       kbv_d=cZERO
     endif
   endif
   !
   ! Eo    are always the eigenvalues consistent with the WFs
   ! E     do also include the QP corrections when Eo are allocated
   !
   if (allocated(Xen%Eo).and.l_eval_dip_iR) &
   &   call msg('rns','[X] Using energies without QP corrections for the dipoles')
   !
 endif
 !
                                      live_t_string='Dipoles: P (T)'
 if (l_eval_DIP_V)                    live_t_string='Dipoles: P and v (T)'
 if (l_eval_DIP_V .and.l_eval_DIP_iR) live_t_string='Dipoles: P, V and iR (T)'
 if (l_eval_DIP_P2.and.l_eval_DIP_V ) live_t_string='Dipoles: P, V and P2 (T)'
 if (l_eval_DIP_P2.and.l_eval_DIP_iR) live_t_string='Dipoles: iR, P, V and P2 (T)'
 !
 n_LT_steps=n_sp_pol*PAR_IND_DIPk_ibz%n_of_elements(PAR_IND_DIPk_ibz_ID+1)*&
&                    PAR_IND_VAL_BANDS_DIP%n_of_elements(PAR_IND_VAL_BANDS_DIP_ID+1)*&
&                    PAR_IND_CON_BANDS_DIP%n_of_elements(PAR_IND_CON_BANDS_DIP_ID+1)
 !
 if (n_LT_steps>0) call live_timing(trim(live_t_string),n_LT_steps)
 !
 ! Main loop over k in IBZ
 !
 do i_sp_pol=1,n_sp_pol
   !
   if (n_LT_steps==0) cycle
   !
   do ik=1,Xk%nibz
     ifrag=ik+(i_sp_pol-1)*Xk%nibz
     ! 
     ! [Vnl,r]
     !
     if(l_use_comm) then
       if (io_KB_pwscf_err==0.and.ifrag>1) then
         IO_ACT_NOW=manage_action(RD_CL_IF_END,ifrag,1,Xk%nibz*n_sp_pol)
         call io_control(ACTION=IO_ACT_NOW,SEC=(/ifrag+1/),ID=ID)
         io_KB_pwscf_err=io_KB_pwscf(ID)
       endif
       !
       if (io_KB_abinit_err==0.and.ifrag>1) then
         IO_ACT_NOW=manage_action(RD_CL_IF_END,ifrag,1,Xk%nibz*n_sp_pol)
         call io_control(ACTION=IO_ACT_NOW,SEC=(/ifrag+1/),ID=ID)
         io_KB_abinit_err=io_KB_abinit(ID)
       endif
       !
     endif
     ! 
     if (.not.PAR_IND_DIPk_ibz%element_1D(ik)) cycle 
     !
     ik_mem=PAR_DIPk_ibz_index(ik)
     !
     ! WF load
     !
     call WF_load(WF,0,1,Dip%ib,(/ik,ik/),sp_pol_to_load=(/i_sp_pol,i_sp_pol/),space='G',&
&                 title='-Oscillators/G space/Transverse '//spin_string(i_sp_pol),force_WFo=l_sc_run,keep_states_to_load=.TRUE.)
     !
     if (io_KB_abinit_err==0.and.l_use_comm) call DIPOLE_kb_abinit_comp(ik,i_sp_pol,Xk,kbv)
     if (io_KB_pwscf_err ==0.and.l_use_comm) call DIPOLE_kb_pwscf_comp(ik,Xk,kbv)
     !
     if (have_cuda .and. (io_KB_abinit_err==0.or.io_KB_pwscf_err ==0) &
&                  .and. l_use_comm.and.size(kbv)>0) call dev_memcpy(kbv_d,kbv)
     !
     do iv=Dip%ib(1),Dip%ib_lim(1) 
       !
       if(.not.PAR_IND_VAL_BANDS_DIP%element_1D(iv)) cycle
       !
       ic_min=max(iv,Dip%ib_lim(2))
       if (l_X_terminator) ic_min=iv
       !
       do ic=ic_min,Dip%ib(2)
         !
         if(.not.PAR_IND_CON_BANDS_DIP%element_1D(ic)) cycle
         !
         iv_wf=WF%index(iv,ik,i_sp_pol)
         ic_wf=WF%index(ic,ik,i_sp_pol)
         !
         if (iv_wf==0) call error(" Error in parallel wf distribution (Dipole iv)")
         if (ic_wf==0) call error(" Error in parallel wf distribution (Dipole ic)")
         !
         ! Evaluate <iv_wf|   p   |ic_wf>
         !================================
         call DIPOLE_p_matrix_elements(Xk,iv_wf,ic_wf,ik,rho,rho_spinor,P2,l_eval_DIP_P2)
         !
         !=====
         ! <P>
         !=====
         ! P_vc=rho
         !
         DIP_P(:,ic,iv,ik_mem,i_sp_pol)=rho
         !
         !======
         ! <P^2>
         !======
         !
         if (l_eval_DIP_P2) P_square(ic,iv,ik_mem,i_sp_pol)= P2
         !
         !============
         ! <P_spinor>
         !============
         !
#if defined _RT
         if (compute_Spin_dipoles.and.n_spinor==2) DIP_P_spinor(:,:,:,ic,iv,ik_mem)=rho_spinor
#endif
         !
         if(.not.(l_eval_dip_V.or.l_eval_dip_iR)) then
           cycle
           call live_timing(steps=1)
         endif
         !
         ! Evaluate <iv_wf|[x,Vnl]|ic_wf>
         !================================
         if (io_Vnl_err==0) rho(:) = rho(:) + Vnl(:3,ic,iv,ik,i_sp_pol)*0.5*real(n_spinor,SP)
         !
         if (io_KB_abinit_err==0.and.pp_kbv_dim_yambo>0) call DIPOLE_kb_sum(ic_wf,iv_wf,rho,DEV_VAR(kbv))
         if (io_KB_pwscf_err ==0.and.pp_kbv_dim_yambo>0) call DIPOLE_kb_sum(ic_wf,iv_wf,rho,DEV_VAR(kbv))
         !
         ! define a different thr for val-val transitions
         ! used for XTerm (here Ev_m_Ev_KS may become very large)
         !
         Dipole_Energy_treshold=Dip%Energy_treshold 
         if(l_X_terminator.and.ic<=Dip%ib_lim(1)) Dipole_Energy_treshold=Dip%Energy_treshold_vv
         !
         !=====
         ! <v>
         !=====
         ! v_vc=rho
         !
         if (l_eval_DIP_V) DIP_v(:,ic,iv,ik_mem,i_sp_pol)=rho
         !
         !======
         ! <iR>
         !======
         !
         if (l_eval_DIP_iR) then
           ! 
           !  [x,p_x]=i we get [x,H] = [x,p^2/2]+[x,Vnl]
           ! 
           ! we gave that 
           ! 
           ! [x,p^2/2]= i p_x 
           !
           ! So from the local part of rho (that is P_vc) we can extract the corresponding local part of <x>
           !
           ! DIP_iR(c,v) = i <v|r|c> = i <v|[r,H]|c>/(Ec-Ev) = 
           !             = i <v|i p|c>/(Ec-Ev) + i<v|[x,Vnl]|c>/(Ec-Ev) =
           !             = - <v|-i grad|c>/(Ec-Ev) +i<v|[x,Vnl]|c>/(Ec-Ev) =
           !             =   <v|-i grad|c>/(Ev-Ec) -i<v|[x,Vnl]|c>/(Ev-Ec) = 
           !             =   P_vc/(Ev-Ec) -i<v|[x,Vnl]|c>/(Ev-Ec)
           !
           !
           if (.not.allocated(Xen%Eo)) Ev_m_Ev_KS=Xen%E (iv,ik,i_sp_pol)-Xen%E (ic,ik,i_sp_pol)
           if (     allocated(Xen%Eo)) Ev_m_Ev_KS=Xen%Eo(iv,ik,i_sp_pol)-Xen%Eo(ic,ik,i_sp_pol)
           !
           if (abs(Ev_m_Ev_KS)> Dipole_Energy_treshold) DIP_iR(:,ic,iv,ik_mem,i_sp_pol)=rho/Ev_m_Ev_KS
           if (abs(Ev_m_Ev_KS)<=Dipole_Energy_treshold) DIP_iR(:,ic,iv,ik_mem,i_sp_pol)=cZERO
           !
         endif
         !
         call live_timing(steps=1)
         !
       enddo    ! conduction band loop
     enddo      ! valence    band loop
     !
     call WF_free(WF)
     ! 
   enddo        ! k-points loop
 enddo          ! sp_pol   loop
 !
 call live_timing()
 !
 ! CLEAN
 !
 if (io_KB_pwscf_err==0.or.io_KB_abinit_err==0) then
   YAMBO_FREE(kbv)
   YAMBO_FREE(kbv_d)
   YAMBO_FREE(pp_n_l_comp)
   YAMBO_FREE(pp_table)
   YAMBO_FREE(pp_kbv_table)
   YAMBO_FREE(pp_factor)
   call PP_free()
 else if (io_Vnl_err==0) then
   YAMBO_FREE(Vnl)
 endif
 YAMBO_FREE(g_vec_d)
 !
 call timing('DIPOLE_transverse',OPR='stop')
 !
end subroutine Dipole_transverse
