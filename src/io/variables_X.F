!
!        Copyright (C) 2000-2020 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM DS
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
integer function variables_X(ID,local_desc,X)
 !
 use units,         ONLY:HA2EV
 use descriptors,   ONLY:IO_desc,IO_desc_reset
 use pars,          ONLY:SP,IP,schlen
 use X_m,           ONLY:X_t,use_X_DbGd,X_DbGd_nkpts,X_DbGd_percentual
 use IO_m,          ONLY:def_variable_elemental,io_variable_elemental,io_status,&
&                        ver_is_gt_or_eq,read_is_on,variable_exist
 !
 implicit none
 !
 integer            ::ID
 type(IO_desc)      ::local_desc
 type(X_t)          ::X
 !
 ! Work Space
 !
 integer             ::sec_size
 logical             ::local_long_gauge
 character(schlen)   ::X_label,VAR_NAME
 !
 call IO_desc_reset(local_desc)
 X_label=' '
 if (ver_is_gt_or_eq(ID,revision=955)) X_label="X_"
 !
 ! PARS_1
 !
 call def_variable_elemental(ID,trim(X_label)//"PARS_1",5,SP,0)
 !
 call io_variable_elemental(ID,DB_I0=X%ng_db,&
&     VAR="X matrix size",I0=X%ng,CHECK=.true.,OP=(/"<="/),DESCRIPTOR=local_desc)
 call io_variable_elemental(ID,&
&     VAR="X band range",I1=X%ib,CHECK=.true.,OP=(/"==","=="/),DESCRIPTOR=local_desc)
 call io_variable_elemental(ID,UNIT=HA2EV,&
&     VAR="X e/h energy range ",TERMINATOR="[eV]",R1=X%ehe,CHECK=.true.,OP=(/">=","<="/),DESCRIPTOR=local_desc)
 !
 ! PARS_2
 !
 VAR_NAME=trim(X_label)//"Time_ordering"
 if (read_is_on(ID) .and. .not. variable_exist(ID,trim(VAR_NAME))) VAR_NAME=trim(X_label)//"PARS_2"
 call def_variable_elemental(ID,trim(VAR_NAME),1,0,0)
 call io_variable_elemental(ID,&
&     VAR="X Time ordering",CH0=X%ordering,WARN=.true.,DESCRIPTOR=local_desc)
 if (ver_is_gt_or_eq(ID,(/3,0,5/))) then
   !
   ! TDDFT_KERNEL
   !
   call def_variable_elemental(ID,trim(X_label)//"TDDFT_KERNEL",1,0,0)
   call io_variable_elemental(ID,VAR="X xc-Kernel",CH0=X%f_xc,CHECK=.true.,DESCRIPTOR=local_desc)
   !
   ! DRUDE
   !
   call def_variable_elemental(ID,trim(X_label)//"DRUDE",2,SP,0)
   call io_variable_elemental(ID,UNIT=HA2EV,&
&     VAR="X Drude frequency",C0=X%Wd,CHECK=.true.,OP=(/"=="/),DESCRIPTOR=local_desc)
   !
 endif
 !
 ! PARS_3
 !
 sec_size=6
 if (ver_is_gt_or_eq(ID,(/3,0,1/)))      sec_size=8
 if (ver_is_gt_or_eq(ID,(/3,0,9/)))      sec_size=9
 if (ver_is_gt_or_eq(ID,revision=15206)) sec_size=10
 call def_variable_elemental(ID,trim(X_label)//"PARS_3",sec_size,SP,0)
 call io_variable_elemental(ID,&
&     VAR="X poles",TERMINATOR="[o/o]",R0=X%cg_percentual,CHECK=.true.,OP=(/"=="/),DESCRIPTOR=local_desc)
 call io_variable_elemental(ID,&
&     VAR="RL vectors in the sum",I0=X%ngostnts,WARN=.true.,OP=(/"<="/),DESCRIPTOR=local_desc)
 call io_variable_elemental(ID,&
&     VAR="[r,Vnl] included",L0=X%Vnl_included,WARN=.true.,OP=(/"=="/),DESCRIPTOR=local_desc)
 !
 if (.not.ver_is_gt_or_eq(ID,(/3,0,9/)).and.read_is_on(ID)) then
   call io_variable_elemental(ID,VAR="Longitudinal Gauge",L0=local_long_gauge,DESCRIPTOR=local_desc)
 endif
 !
 call io_variable_elemental(ID,&
&     VAR="Field direction",R1=X%q0,CHECK=.true.,OP=(/"==","==","=="/),DESCRIPTOR=local_desc)
 !
 if (ver_is_gt_or_eq(ID,(/3,0,1/))) then
   call io_variable_elemental(ID,&
&       VAR="BZ energy Double Grid",L0=use_X_DbGd,WARN=.true.,OP=(/"=="/),DESCRIPTOR=local_desc)
   call io_variable_elemental(ID,&
&       VAR="BZ energy DbGd points",I0=X_DbGd_nkpts,WARN=.true.,OP=(/"=="/),DESCRIPTOR=local_desc)
   if (ver_is_gt_or_eq(ID,revision=15206)) then
     call io_variable_elemental(ID,&
&         VAR="BZ Q point size factor  ",R0=X_DbGd_percentual,WARN=.true.,OP=(/"=="/),DESCRIPTOR=local_desc)
   endif
 endif
 !
 variables_X=io_status(ID)
 !
end function
