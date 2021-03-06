!
!        Copyright (C) 2000-2020 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): DS
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
subroutine RT_DBs_carriers_setup(en,kpt,qpt)
 !
 use pars,          ONLY:SP,schlen
 use units,         ONLY:HA2KEL
 use electrons,     ONLY:levels
 use IO_m,          ONLY:io_control,OP_WR_CL,REP
 use R_lattice,     ONLY:bz_samp
 use D_lattice,     ONLY:Bose_Temp
 use RT_control,    ONLY:CARR_RT_IO_t
 use parallel_m,    ONLY:PAR_G_k_range
 use real_time,     ONLY:RT_carriers,NE_i_time,l_elel_scatt,l_elph_scatt,&
&                        l_elphoton_scatt,RT_potential
 use YPP_real_time, ONLY:l_RTpump_energy,l_RTpump_kspace,l_RTpump_Fermi
 !
 implicit none
 !
 type(levels), intent(inout) :: en
 type(bz_samp),intent(in)    :: kpt,qpt
 !
 ! Work Space
 !
 integer           :: io_RT_err,ID
 integer, external :: io_RT_components
 logical           :: SUCCESS
 character(schlen) :: sec_ch
 !
 if (l_RTpump_energy) sec_ch="Energy selection"
 if (l_RTpump_kspace) sec_ch="K-space selection"
 if (l_RTpump_Fermi)  sec_ch="Fermi function"
 !
 call section('*','Manual carriers excitation via '//trim(sec_ch))
 !
 ! Force a tiny temperature to allocate EP_abs components
 !
 Bose_Temp=1/HA2KEL
 !
 NE_i_time   =1
 PAR_G_k_range=(/1,kpt%nibz/)
 !
 l_elel_scatt    =.true.
 l_elph_scatt    =.true.
 l_elphoton_scatt=.true.
 RT_potential    ="HARTREE+GS_xc"
 !
 call RT_k_grid(en,kpt,qpt)
 !
 call RT_alloc(en,"carriers")
 !
 call RT_carriers_object(RT_carriers,en,kpt,ID,"allocate")
 !
 if(l_RTpump_energy .or. l_RTpump_kspace) call RT_manual_excitation(en,kpt,SUCCESS)
 !
 if(l_RTpump_Fermi)                       call RT_Fermi_excitation(en,kpt,SUCCESS)
 !
 if (.not.SUCCESS) then
   call warning("No level to be manually pumped found")
   return
 endif
 !
 CARR_RT_IO_t%N=1
 allocate(CARR_RT_IO_t%Time(1))
 CARR_RT_IO_t%Time(CARR_RT_IO_t%N)=0._SP
 !
 call io_control(ACTION=OP_WR_CL,SEC=(/1,2,3/),COM=REP,ID=ID)
 io_RT_err=io_RT_components("carriers",ID)
 !
 call RT_carriers_object(RT_carriers,en,kpt,ID,"free")
 !
 call RT_free("carriers")
 !
end subroutine
