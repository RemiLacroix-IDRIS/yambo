!
!        Copyright (C) 2000-2020 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): MG,DV
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
subroutine scatter_ModScr(isc,mu)
 !
 ! multiply scatterGamp by exp((-|q+G|^2)/(4\mu^2))
 !
 use pars,          ONLY:SP,pi
 use collision_el,  ONLY:elemental_collision
 use drivers,       ONLY:l_col_cut
 use R_lattice,     ONLY:bare_qpg,d3q_factor
 use global_XC,     ONLY:WF_xc_functional
 use xc_functionals,ONLY:XC_HYB_GGA_XC_GAUPBE,XC_FACTOR
 use cuda_m,     ONLY:have_cuda
 use deviceXlib_m,   ONLY:dev_memcpy 

 !
 implicit none
 !
 type(elemental_collision)::isc
 real(SP)                 :: mu,Co,bare_qpg_true
 !
 !Working Space
 !
 integer :: ng(2),ig1,ig2,iq,i1,i2
 !
 iq=isc%qs(2)
 isc%iqref=iq
 !
 ng=shape(isc%gamp)
 !
 Co=(pi/mu)**(3._SP/2._SP)/(4._SP*pi)*d3q_factor/(2._SP*pi)**3
 do i1=1,ng(1)
   do i2=1,ng(2)
     ig1=i1
     ig2=i2
     if (ng(1)==1) ig1=ig2
     if (ng(2)==1) ig2=ig1
     if (l_col_cut) then
       call set_qpg_true(iq,ig1,bare_qpg_true)
     else
       bare_qpg_true=bare_qpg(iq,ig1)
     endif
     if (WF_xc_functional==XC_HYB_GGA_XC_GAUPBE*XC_FACTOR) then 
!GAUPBE expression for model exchange see: Song et al. J. Chem. Phys. 138, 241101 (2013)
       isc%gamp(i1,i2)= Co*real(exp(-(bare_qpg_true**2)/(4._SP*mu)),SP)
     else
!       isc%gamp(i1,i2)=isc%gamp(i1,i2)*&
!            &(1._SP-real(exp(-(bare_qpg(iq,ig1)**2)/(4._SP*mu**2)),SP)) 
!In case of bare potential lim->q=0 4pi/q^2(1-exp(-q^2/4mu^2)=pi/mu^2 this is
!not taken into account
!Note in case of cutoff potential QE does not screen the exchange term: to be
!verified if it is coorect, this is not correct. QE in any case use
!gygi-baldereschi method at the moment not implemented in Yambo.
       isc%gamp(i1,i2)=isc%gamp(i1,i2)*&
            &(1._SP -real(exp(-(bare_qpg_true**2)/(4._SP*mu**2)),SP)) 
       if (i1==1) isc%gamp(i1,i2)=1._SP/(4._SP*mu**2)*d3q_factor/(2._SP*pi)**3
     endif
   enddo
 enddo
 !
 if (have_cuda) call dev_memcpy(isc%gamp_d,isc%gamp)
 !
 contains
   !
   subroutine set_qpg_true(iq,ig1,bare_qpg_true)
   use vec_operate,   ONLY:iku_v_norm
   use R_lattice,     ONLY:q_norm,g_vec,q_pt
   real(SP)::bare_qpg_true
   integer ::ig1,iq
   !
 
    if (iq==1.and.ig1==1)  then
      bare_qpg_true=q_norm(1)
    elseif(iq==1.and.ig1 > 1) then
      bare_qpg_true=iku_v_norm(g_vec(ig1,:))
    else
      bare_qpg_true=iku_v_norm(q_pt(iq,:)+g_vec(ig1,:))
    endif

   end subroutine set_qpg_true
   !
 end subroutine scatter_ModScr


