!
!        Copyright (C) 2000-2020 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): DS, AM, MG
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
subroutine K_diago_response_functions(iq,i_BS_mat,W,BS_E,BS_R_left,BS_R_right,BS_E_SOC_corr,&
 &                                  BS_R_left_magn,BS_R_right_magn,BS_R_right_kerr,BS_R_PL)
 !
 ! eps2(iw)= 1 - Sum  [BS_R_left(i)*BS_R_right(i)] / [w+i*eta - E(i)]  
 !
 use pars,           ONLY:cZERO,cONE,SP,pi,rZERO
 use X_m,            ONLY:Epsilon_ii,Joint_DOS,BS_E_sorted,X_drude_term,global_gauge,skip_cond_sum_rule
 use electrons,      ONLY:n_sp_pol
 use frequency,      ONLY:w_samp
 use parallel_int,   ONLY:PP_redux_wait,PARALLEL_index
 use parallel_m,     ONLY:myid,PP_indexes,PP_indexes_reset
 use LIVE_t,         ONLY:live_timing
 use BS,             ONLY:BS_perturbative_SOC,BS_mat_res_ares_dim,l_BS_abs,l_BS_jdos,l_BS_esort
 use BS_solvers,     ONLY:BSS_n_eig,BSS_add_antiresonant,Co_factor,diam_term_exact,BSS_eels_to_eps
 use R_lattice,      ONLY:bare_qpg
 use units,          ONLY:HA2EV
 use vec_operate,    ONLY:degeneration_finder,sort
 use BS_solvers,     ONLY:B_Hall
 use X_m,            ONLY:Epsilon_ij,X_magnons
 use PHOTOLUM,       ONLY:PL,PL_prefactor
 use BS,             ONLY:l_BS_kerr,l_BS_anomalous_Hall,l_BS_magnons,l_BS_photolum,l_BS_dichroism
 !
 implicit none
 !
 type(w_samp),intent(in)  :: W
 integer,     intent(in)  :: iq,i_BS_mat
 complex(SP), intent(in)  :: BS_E(BSS_n_eig)
 complex(SP), pointer, intent(in) :: BS_R_left(:),BS_R_right(:)
 real(SP),    pointer, intent(in) :: BS_E_SOC_corr(:,:)
 complex(SP), pointer, intent(in) :: BS_R_left_magn(:,:),BS_R_right_magn(:,:)
 complex(SP), pointer, intent(in) :: BS_R_right_kerr(:)
 real(SP),    pointer, intent(in) :: BS_R_PL(:,:)
 !
 ! Work space
 !
 type(PP_indexes)     ::px
 !
 integer              :: i1,i_pert_SOC,n_SOC,ares_fac
 complex(SP)          :: para_term_w0,diam_term_used,EXC_E(2/n_sp_pol),res_abs
 !
 integer  :: i_VAR,i_grp,i_lambda,nVAR,EDIM,n_deg_grp
 real(SP), allocatable     :: vtmpR(:)
 complex(SP), allocatable  :: BS_E_sorted_tmp(:,:)
 integer, allocatable      :: sort_indx(:),first_exc(:),n_of_exc(:)
 complex(SP)               :: gauge_factor,res_kerr,res_magn(2)
 !
 n_SOC=1
 ares_fac=(-1)**(i_BS_mat-1)
 !
 if( BS_perturbative_SOC.and.n_sp_pol==1) n_SOC=2
 !
 if(l_BS_esort.and.i_BS_mat==1) then
   EDIM=BSS_n_eig
   nVAR=2
   if(l_BS_abs)       nVAR=nVAR+1
   if(l_BS_kerr)      nVAR=nVAR+1
   if(l_BS_dichroism) nVAR=nVAR+1
   if(l_BS_magnons)   nVAR=nVAR+2
   allocate(BS_E_sorted_tmp(EDIM,nVAR))
   BS_E_sorted_tmp=cZERO
 endif
 !
 para_term_w0=cZERO
 !
 ! If perturbative SOC energies are loaded compute the SOC energies
 !
 call PP_indexes_reset(px)
 call PARALLEL_index(px,(/BSS_n_eig/))
 !
 call live_timing('BSK resp. funct',px%n_of_elements(myid+1))
 !
 do i1=1,BSS_n_eig
   !
   if (.not.px%element_1D(i1)) cycle
   !
   if (l_BS_kerr.and.l_BS_anomalous_Hall) then
     if (trim(global_gauge)=='length'  ) gauge_factor=cONE
     if (trim(global_gauge)=='velocity') gauge_factor=BS_E(i1)
     B_Hall(2)=B_Hall(2)+   BS_R_left(i1)*BS_R_right_kerr(i1) / gauge_factor **2._SP
   endif
   !
   if (     BS_perturbative_SOC) EXC_E(:)=BS_E(i1)+BS_E_SOC_corr(:,i1)
   !
   if (.not.BS_perturbative_SOC) EXC_E(1)=BS_E(i1)
   !
   do i_pert_SOC=1,n_SOC
     !
     if(l_BS_esort.and.i_BS_mat==1) then
       BS_E_sorted_tmp(i1,1)=EXC_E(1)
       nVAR=2
     endif
     !
     if(l_BS_jdos) then
       Joint_DOS(:,2)=Joint_DOS(:,2)-ares_fac/(W%p(:)-EXC_E(i_pert_SOC))
       if (BSS_add_antiresonant.and.BS_mat_res_ares_dim==1) then
         Joint_DOS(:,2)=Joint_DOS(:,2)+1._SP/(W%p(:)+conjg(EXC_E(i_pert_SOC)))
       endif
     endif
     !
     if(l_BS_abs) then
       res_abs=BS_R_left(i1)*BS_R_right(i1)*ares_fac
       if(l_BS_esort.and.i_BS_mat==1) then
         BS_E_sorted_tmp(i1,nVAR+1:nVAR+1)=res_abs
         nVAR=nVAR+1
       endif
       Epsilon_ii(:,2)=Epsilon_ii(:,2)-res_abs/(W%p(:)-EXC_E(i_pert_SOC))
       if (BSS_add_antiresonant.and.BS_mat_res_ares_dim==1) then
         Epsilon_ii(:,2)=Epsilon_ii(:,2)+conjg(res_abs)/(W%p(:)+conjg(EXC_E(i_pert_SOC)))
       endif
       !
       if(trim(global_gauge)=='length')   para_term_w0=para_term_w0+res_abs*EXC_E(i_pert_SOC)/bare_qpg(1,1)**2
       if(trim(global_gauge)=='velocity') para_term_w0=para_term_w0+res_abs/EXC_E(i_pert_SOC)
     endif
     !
     if(l_BS_kerr) then
       res_kerr=BS_R_left(i1)*BS_R_right_kerr(i1)*ares_fac
       if(l_BS_esort.and.i_BS_mat==1) then
         BS_E_sorted_tmp(i1,nVAR+1:nVAR+1)=res_kerr
         nVAR=nVAR+1
       endif
       Epsilon_ij(:,2)=Epsilon_ij(:,2)-res_kerr/(W%p(:)-EXC_E(i_pert_SOC))
       if (BSS_add_antiresonant.and.BS_mat_res_ares_dim==1) then
         Epsilon_ij(:,2)=Epsilon_ij(:,2)+conjg(res_kerr)/(W%p(:)+conjg(EXC_E(i_pert_SOC)))
       endif
     endif
     if(l_BS_magnons) then
       res_magn(:)=BS_R_left_magn(:,i1)*BS_R_right_magn(:,i1)*ares_fac
       if(l_BS_esort.and.i_BS_mat==1) then
         BS_E_sorted_tmp(i1,nVAR+1:nVAR+2)=res_magn
         nVAR=nVAR+2
       endif
       X_magnons(:,1,2)=X_magnons(:,1,2)-res_magn(1)/(W%p(:)-EXC_E(i_pert_SOC))
       X_magnons(:,2,2)=X_magnons(:,2,2)-res_magn(2)/(W%p(:)-EXC_E(i_pert_SOC))
       if (BSS_add_antiresonant.and.BS_mat_res_ares_dim==1) then
         X_magnons(:,1,2)=X_magnons(:,1,2)+conjg(res_magn(2))/(W%p(:)+conjg(EXC_E(i_pert_SOC)))
         X_magnons(:,2,2)=X_magnons(:,2,2)+conjg(res_magn(1))/(W%p(:)+conjg(EXC_E(i_pert_SOC)))
       endif
     endif
     if(l_BS_photolum) then
       PL(:,2)=PL(:,2)+PL_prefactor*ares_fac*BS_R_PL(1,i1)*aimag(-1._SP/(W%p(:)-EXC_E(i_pert_SOC)))/pi
       if (BSS_add_antiresonant.and.BS_mat_res_ares_dim==1) then
         PL(:,2)=PL(:,2)+PL_prefactor*BS_R_PL(2,i1)*aimag(-1._SP/(W%p(:)+conjg(EXC_E(i_pert_SOC))))/pi
       endif
     endif
     !
   enddo
   !
   call live_timing(steps=1)
 enddo
 call live_timing
 !
 call PP_indexes_reset(px)
 !
 if(l_BS_esort.and.i_BS_mat==1) then
   call PP_redux_wait(BS_E_sorted_tmp )
   allocate(vtmpR(EDIM)); allocate(sort_indx(EDIM))
   vtmpR=real(BS_E_sorted_tmp(:,1),SP)
   call sort(arrin=vtmpR,indx=sort_indx)
   do i1=1,EDIM
     if(vtmpR(i1)>0._SP) exit
   enddo
   i1=max(1,i1-100)
   EDIM=min(BSS_n_eig-i1+1,10000)
   allocate(first_exc(EDIM));   allocate(n_of_exc(EDIM))
   ! Threshold is 1meV
   call degeneration_finder(vtmpR(i1:i1-1+EDIM),EDIM,first_exc,n_of_exc,n_deg_grp,0.001_SP/HA2EV,Include_single_values=.TRUE.)
   EDIM=min(BSS_n_eig-i1+1,1000)
   do i_VAR=1,nVAR
     BS_E_sorted(:,i_VAR,2)=cZERO
     do i_grp=1,n_deg_grp
       if(i_grp>EDIM) cycle
       if(i_VAR==2) then
         BS_E_sorted(i_grp,i_VAR,2)=real(n_of_exc(i_grp),SP)
         cycle
       endif
       do i_lambda=first_exc(i_grp)+i1-1,first_exc(i_grp)+n_of_exc(i_grp)-1+i1-1
         BS_E_sorted(i_grp,i_VAR,2)=BS_E_sorted(i_grp,i_VAR,2)+BS_E_sorted_tmp(sort_indx(i_lambda),i_VAR)
       enddo
       BS_E_sorted(i_grp,i_VAR,2)=BS_E_sorted(i_grp,i_VAR,2)/real(n_of_exc(i_grp),SP)
     enddo
   enddo
   deallocate(BS_E_sorted_tmp)
 endif
 !
 if (BS_mat_res_ares_dim/=i_BS_mat) return
 !
 if(l_BS_jdos)  call PP_redux_wait(Joint_DOS(:,2) )
 !
 if(l_BS_abs) then
   call PP_redux_wait(Epsilon_ii(:,2))
   call PP_redux_wait(para_term_w0)
   if (BSS_add_antiresonant) para_term_w0=para_term_w0+conjg(para_term_w0)
 endif
 !
 if(l_BS_photolum) then
   call PP_redux_wait(PL(:,2))
 endif
 !
 if(l_BS_kerr) then
   call PP_redux_wait(Epsilon_ij(:,2))
   if(l_BS_anomalous_Hall) call PP_redux_wait(B_Hall(2))
 endif
 !
 if(l_BS_magnons) then
   call PP_redux_wait(X_magnons(:,:,2))
 endif
 !
 if(l_BS_abs) then
   if (trim(global_gauge)=='velocity') then
     if (     skip_cond_sum_rule) diam_term_used=diam_term_exact
     if (.not.skip_cond_sum_rule) diam_term_used=para_term_w0
   endif
   !
   if(trim(global_gauge)=='length'  ) Epsilon_ii(:,2)= (Epsilon_ii(:,2)               )*Co_factor/bare_qpg(iq,1)**2
   if(trim(global_gauge)=='velocity') Epsilon_ii(:,2)= (Epsilon_ii(:,2)-diam_term_used)*Co_factor/  W%p(:)  **2
   !
   if(BSS_eels_to_eps) Epsilon_ii(:,2)=(1._SP-Epsilon_ii(:,2))**(-1)-1._SP
   !
   ! Drude term
   !============
   if (skip_cond_sum_rule) X_drude_term(:)=(para_term_w0-diam_term_exact)*Co_factor/W%p(:)**2
 endif
 !
 if(l_BS_jdos) then
   Joint_DOS(:,2)=Joint_DOS(:,2)*Co_factor !/(4._SP*pi) is needed for the correct Jdos
 !                                         ! However it is commented for now since all test-suite
 !                                         ! references needs to be updated before insterting it
 endif
 !
 if(l_BS_kerr) then
   if(trim(global_gauge)=='length'  ) Epsilon_ij(:,2)=Epsilon_ij(:,2)*Co_factor/bare_qpg(iq,1)**2
   if(trim(global_gauge)=='velocity') Epsilon_ij(:,2)=Epsilon_ij(:,2)*Co_factor/    W%p(:)    **2
   !
   if(l_BS_anomalous_Hall) then
     if(BSS_add_antiresonant) B_Hall(2)=B_Hall(2)-conjg(B_Hall(2))
     if(trim(global_gauge)=='length'  ) B_Hall(2)=B_Hall(2)*Co_factor/bare_qpg(iq,1)**2
     if(trim(global_gauge)=='velocity') B_Hall(2)=B_Hall(2)*Co_factor
     !
     ! I add the term describing the Anomalous Hall effect which is
     ! missing in the length gauge (this should be zero for systems with a gap)
     if (trim(global_gauge)=='length') Epsilon_ij(:,2)=Epsilon_ij(:,2)+B_Hall(2)/W%p(:)
     !
   endif
   !
 endif
 !
 if (l_BS_magnons) X_magnons(:,:,2)=X_magnons(:,:,2)*Co_factor/(4._SP*pi)
 !
end subroutine K_diago_response_functions
