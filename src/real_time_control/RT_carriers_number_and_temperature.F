!
!        Copyright (C) 2000-2020 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): DS AM
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
subroutine RT_carriers_number(en,k,Ncarr)
 !
 use pars,           ONLY:SP
 use R_lattice,      ONLY:bz_samp
 use electrons,      ONLY:levels
 use RT_control,     ONLY:NE_i_start_time
 use RT_occupations, ONLY:RT_el_occ,RT_ho_occ
 use real_time,      ONLY:RTibz,NE_i_time,RT_levels,RT_bands
 !
 implicit none
 !
 type(levels),  intent(in) :: en
 type(bz_samp), intent(in) :: k
 real(SP),      intent(out):: Ncarr(3)
 !
 ! Workspace
 !
 integer     :: ib,ik,ik_RT
 real(SP)    :: VALUE_tmp(2)
 !
 ! Electrons and holes number
 !
 Ncarr = 0._SP
 !
 do ik=1,en%nk
   do ib=RT_bands(1),RT_bands(2)
     VALUE_tmp=0._SP
     do ik_RT=RTibz%k_range(ik,1),RTibz%k_range(ik,2)
       if ( RT_levels%E(ib,ik_RT,1)<=0._SP ) then
         if (NE_i_time==NE_i_start_time) VALUE_tmp(1)=VALUE_tmp(1)+RT_ho_occ%N(ib,ik_RT)*RTibz%weights(ik_RT)
         if (NE_i_time/=NE_i_start_time) VALUE_tmp(1)=VALUE_tmp(1)-RT_el_occ%dN(ib,ik_RT)*RTibz%weights(ik_RT)
       else
         if (NE_i_time==NE_i_start_time) VALUE_tmp(2)=VALUE_tmp(2)+RT_el_occ%N(ib,ik_RT)*RTibz%weights(ik_RT)
         if (NE_i_time/=NE_i_start_time) VALUE_tmp(2)=VALUE_tmp(2)+RT_el_occ%dN(ib,ik_RT)*RTibz%weights(ik_RT)
       endif
     enddo
     Ncarr(2:3)=Ncarr(2:3)+VALUE_tmp
   enddo
 enddo
 !
 Ncarr(1)=Ncarr(2)-Ncarr(3)
 !
end subroutine RT_carriers_number
!
subroutine RT_temperature(Tfit,EfFit)
 !
 use pars,           ONLY:SP
 use units,          ONLY:HA2KEL,HA2EV
 use drivers,        ONLY:l_elel_scatt,l_elph_scatt
 use RT_occupations, ONLY:RT_el_occ
 !
 implicit none
 !
 real(SP),    intent(inout):: Tfit(2),EfFit(2)
 !
 ! Workspace
 !
 ! Electrons and holes temperatures
 !
 Tfit =0._SP
 EfFit=0._SP
 !
 if ( (l_elel_scatt.or.l_elph_scatt)) then
   !
   call RT_occupations_FIT(Tfit,EfFit,RT_el_occ%N)
   !
   if (abs(Tfit(1))>50000._SP/HA2KEL) then
     Tfit(1)=0._SP
     EfFit(1)=0._SP
   endif
   if (abs(Tfit(2))>50000._SP/HA2KEL) then
     Tfit(2)=0._SP
     EfFit(2)=0._SP
   endif
   !
   EfFit=EfFit*HA2EV
   Tfit =Tfit*HA2KEL
   !
 endif
 !
end subroutine RT_temperature
