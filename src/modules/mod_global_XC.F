!
! Copyright (C) 2000-2008 A. Marini and the YAMBO team
!              http://www.yambo-code.org
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
module global_XC
 !
 use pars,      ONLY:lchlen
 implicit none
 !
 ! Energies (linked to the three energy types)
 !
 integer     , public :: G_kind,G_xc_functional,G_SE_more
 integer     , public :: X_kind,X_xc_functional,X_SE_more
 integer     , public :: K_kind,K_xc_functional,K_SE_more
 !
 ! QP database
 !
 integer     , public :: QP_DB_kind
 !
 ! Wavefunctions
 !
 integer     , public :: WF_kind,WF_xc_functional
 !
 ! Strings... to be used in io_header, so linked to the databases
 !
 ! ... these are defined with the above integers
 !
 character(lchlen) , public :: G_E_xc_string
 character(lchlen) , public :: X_E_xc_string(4)
 character(lchlen) , public :: K_E_xc_string
 !
 ! ... these are read from the DB (when writing WF_global_xc_string is used)
 !
 character(lchlen) , public :: G_WF_xc_string
 character(lchlen) , public :: X_WF_xc_string(4)
 character(lchlen) , public :: K_WF_xc_string
 !
 character(lchlen) , public :: WF_global_xc_string  ! ... set in wf_load after rotation
 !
 ! SC's and Self Energies are KINDS
 !
 ! SC's
 integer, public, parameter :: &
   SC_EXX        = 301, &  ! OEP-EXX
   SC_HF         = 302, &  ! Hartree-Fock
   SC_CHOSEX     = 303, &  ! Coulomb-Hole Screened-eXchange
   SC_EXXC       = 304     ! OEP-EXX + LDA correlation
 !
 ! Self Energies
 integer, public, parameter :: &
   SE_NONE          = 400, &
   SE_CHOSEX        = 401, &
   SE_GoWo_PPA      = 402, &
   SE_GoWo          = 403, &
   SE_GWo_PPA       = 404, &
   SE_GWo           = 405
 !
 ! More Self-Energies
 integer, public, parameter :: &
   MORE_NONE          = 501, &
   MORE_SCISSOR       = 502, &
   MORE_STRETCH       = 503, &
   MORE_SCIS_AND_STRE = 504, &
   MORE_INTERPOLATION = 505
   !
 contains
   !
   subroutine  setup_global_XC(what,kind,se_more,xc_functional)
     character(*)      :: what          
     integer           :: kind          
     integer, optional :: se_more       
     integer, optional :: xc_functional 
     !
     ! Work Space
     !
     integer :: local_se_more,local_xc_functional
     !
     local_se_more=MORE_NONE
     local_xc_functional=0
     if (present(se_more)) local_se_more=se_more
     if (present(xc_functional)) local_xc_functional=xc_functional
     !
     if (what=='E'.or.what=='preset'.or.what=='G') then
       G_kind=kind
       G_SE_more=local_se_more
       G_xc_functional=local_xc_functional
       G_E_xc_string=global_XC_string(kind,local_se_more,local_xc_functional)
     endif
     !
     if (what=='X'.or.what=='preset') then
       X_kind=kind
       X_SE_more=local_se_more
       X_xc_functional=local_xc_functional
       X_E_xc_string=global_XC_string(kind,local_se_more,local_xc_functional)
     endif
     !
     if (what=='K'.or.what=='preset') then
       K_kind=kind
       K_SE_more=local_se_more
       K_xc_functional=local_xc_functional
       K_E_xc_string=global_XC_string(kind,local_se_more,local_xc_functional)
     endif
     !
     if (what=='WF'.or.what=='preset') then
       WF_kind=kind
       WF_xc_functional=local_xc_functional
       WF_global_xc_string=global_XC_string(kind,MORE_NONE,local_xc_functional)
       G_WF_xc_string=WF_global_xc_string
       X_WF_xc_string=WF_global_xc_string
       K_WF_xc_string=WF_global_xc_string
     endif
     !
     if (what=='preset') QP_DB_kind=SE_none
     !
   end subroutine
   !
   character(lchlen) function global_XC_string(kind,se_more,xc_functional)
     !
     use xc_functionals,  ONLY:xc_string,XC_CORRELATION
     !
     integer           :: kind          ! <300 (LDA's GGa's ...) >300 See above
     integer           :: se_more       ! scissor's and more
     integer           :: xc_functional ! In case kind < 300 gives DFT functional
     ! 
     character(1)      :: ch_plus
     character(lchlen) :: ch
     !
     global_XC_string=' '
     select case (kind)
       case(0)
         global_XC_string='Hartree'
       case(1:300)
         global_XC_string=trim(xc_string(kind,xc_functional))
       case(SC_EXX)
         global_XC_string='SC Exact Exchange'
       case(SC_EXXC)
         global_XC_string='SC Exact Exchange +'//trim(xc_string(XC_CORRELATION,xc_functional))
       case(SC_HF)
         global_XC_string='SC Hartee Fock'
       case(SC_CHOSEX)
         global_XC_string='SC CHOSEX'
       case(SE_CHOSEX)
         global_XC_string='CHOSEX'
       case(SE_GoWo_PPA)
         global_XC_string='GoWo Plasmon Pole appox.'
       case(SE_GoWo)
         global_XC_string='GoWo on real axis'
       case(SE_GWo_PPA)
         global_XC_string='GWo Plasmon Pole appox.'
       case(SE_GWo)
         global_XC_string='GWo on real axis'
     end select
     !
     ch_plus='+'
     if (kind==0) ch_plus=' '
     !
     if (se_more/=MORE_NONE) then
       ch=global_XC_string
       select case (se_more)
         case(MORE_SCISSOR)
           global_XC_string=trim(ch)//trim(ch_plus)//'Scissor'
         case(MORE_STRETCH)
           global_XC_string=trim(ch)//trim(ch_plus)//'Stretching'
         case(MORE_SCIS_AND_STRE)
           global_XC_string=trim(ch)//trim(ch_plus)//'Scissor & Stretching'
         case(MORE_INTERPOLATION)
           global_XC_string=trim(ch)//trim(ch_plus)//'Interpolation'
       end select
     endif
     !
   end function
   !
end module 