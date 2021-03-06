!
!        Copyright (C) 2000-2020 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM CA
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
subroutine RT_X_response(en,k,q)
 !
 use YPP_real_time,  ONLY:Use_FFT,Pol,Curr,N_probe_frequencies,&
&                         N_probes,N_pumps,RT_OBSERVABLES_IO,X_order,&
&                         l_RT_X_inversion,Probe_path,Pump_path,N_probes,RT_conf,l_skip_OBS_IO
 use RT_control,     ONLY:OBS_RT_IO_t
 use pars,           ONLY:lchlen
 use R_lattice,      ONLY:bz_samp
 use electrons,      ONLY:levels
 use fields,         ONLY:Efield
 use com,            ONLY:jobstr
 use parser_m,       ONLY:parser
 !
#include<memory.h>
 !
 type(levels)  :: en
 type(bz_samp) :: k,q
 !
 ! Work Space
 !
 integer           :: i_f,i_Probe
 character(lchlen) :: jobstr_save
 logical           :: l_RT_LRR_real_field,l_RT_X_effective,l_RT_SHG_qssin
 !
 call RT_OBSERVABLES_IO_paths('JP',en)
 !
 i_Probe=1
 !
 l_RT_LRR_real_field= all((/&
&   .not.any((/trim(Efield(i_Probe)%ef_name)=="ANTIRES",trim(Efield(i_Probe)%ef_name)=="RES",&
&   trim(Efield(i_Probe)%ef_name)=="SIN"/)),N_pumps==0, N_probes==1, X_order==1/) )
 !
 l_RT_SHG_qssin     = all( (/ trim(Efield(i_Probe)%ef_name)=="QSSIN" , N_pumps==0, N_probes==1, X_order==2/) )
 !
 l_RT_X_effective   = all((/any((/trim(Efield(i_Probe)%ef_name)=="ANTIRES",trim(Efield(i_Probe)%ef_name)=="SIN"/)),X_order>=0/))
 !
 if (l_RT_X_effective) l_RT_X_inversion=all((/ X_order>=0, N_probe_frequencies==1, N_pumps==0/))
 !
 if ( .not.any((/l_RT_LRR_real_field,l_RT_SHG_qssin,l_RT_X_effective/)) ) return
 !
 ! Time Initialization
 !====================
 call RT_time_configuration_setup('CURRENT',OBS_RT_IO_t)
 !
 ! Field-Dependent actions
 !=========================
 if ( any((/l_RT_LRR_real_field,l_RT_SHG_qssin/)) ) then
   !
   ! Database
   !
   ! Search the database in JOBSTR,Pump_path and Probe_path
   !
   call RT_OBSERVABLES_IO( what='JP' )
   !
   jobstr_save=jobstr
   if (.not.allocated(Curr%F_t)) then
     jobstr=trim(Pump_path)
     call RT_OBSERVABLES_IO(what='JP', mesg=trim(Pump_path))
   endif
   if (.not.allocated(Curr%F_t)) then
     do i_f=1,N_probes
       jobstr=trim(Probe_path(i_f))
       call RT_OBSERVABLES_IO( what='JP', mesg=trim(Pump_path))
       if (allocated(Curr%F_t)) exit
     enddo
   endif
   jobstr=trim(jobstr_save)
   !
   if (.not.allocated(Curr%F_t)) call error('J and P databases not found')
   !
   !  Initialization 
   !
   if ( l_RT_LRR_real_field.or. l_RT_SHG_qssin) then 
     call RT_OBSERVABLES_damp_and_write(Pol,RT_conf,l_skip_OBS_IO)
     call RT_OBSERVABLES_damp_and_write(Curr,RT_conf,l_skip_OBS_IO)
   endif
   !
   if ( l_RT_LRR_real_field ) then
     !
     ! CORE Logicals
     !---------------
     ! 
     call parser('UseFFT',Use_FFT)
     !
     ! OPTICS
     !--------
     !
     call RT_X_LRR_real_field(en)
     !
   else if ( l_RT_SHG_qssin ) then
     !
     ! DEBUG>
     !call RT_X_QSSIN(en)
     ! DEBUG<
     !
   endif
   !
 else if ( l_RT_X_effective ) then
   !
   ! DEBUG>
   !call RT_X_effective(en)
   ! DEBUG<
   !
 endif
 !
 ! CLEAN
 !
 YAMBO_FREE(Pol%F_t)
 YAMBO_FREE(Curr%F_t)
 !
end subroutine
