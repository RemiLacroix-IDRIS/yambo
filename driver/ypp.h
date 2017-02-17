/*
  Copyright (C) 2000-2008 A. Marini and the YAMBO team 
               http://www.yambo-code.org
  
  This file is distributed under the terms of the GNU 
  General Public License. You can redistribute it and/or 
  modify it under the terms of the GNU General Public 
  License as published by the Free Software Foundation; 
  either version 2, or (at your option) any later version.
 
  This program is distributed in the hope that it will 
  be useful, but WITHOUT ANY WARRANTY; without even the 
  implied warranty of MERCHANTABILITY or FITNESS FOR A 
  PARTICULAR PURPOSE.  See the GNU General Public License 
  for more details.
 
  You should have received a copy of the GNU General Public 
  License along with this program; if not, write to the Free 
  Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
  MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
*/
/*
 Driver declaration
*/
#if defined _FORTRAN_US
 int ypp_i
#else
 int ypp_i_
#endif
 (char *str1,int *,char *inf,int *,char* id,
  int *,char *od,int *,char *com_dir,int *,char *js,int *,int *,int *); 
/*
 Command line structure
*/
 static Ldes opts[] = { /* Int Real Ch (Dummy)*/
  {"help",  "h","Short Help",0,0,0,0}, 
  {"lhelp", "H","Long Help",0,0,0,0}, 
  {"jobstr","J","Job string identifier",0,0,1,0},   
  {"infver", "V","Input file verbosity",1,0,0,0}, 
  {"ifile", "F","Input file",0,0,1,0},              
  {"idir",  "I","Core I/O directory",0,0,1,0},         
  {"odir",  "O","Additional I/O directory",0,0,1,0},        
  {"cdir",   "C","Communications I/O directory",0,0,1,0},
  {"nompi", "N","Skip MPI initialization",0,0,0,0}, 
  {"dbfrag","S","DataBases fragmentation",0,0,0,0}, 
  {"bzgrids","k","BZ Grid generator [(k)pt,(q)pt,(l)ongitudinal]",0,0,1,0}, 
  {"excitons", "e","Excitons  [(s)ort,(a)mplitude,(w)ave]",0,0,1,0}, 
  {"electrons","l","Electrons [(w)ave,(d)ensity]",0,0,1,0}, 
  {"freehole","f","Free hole position [excitons plot]",0,0,0,0}, 
  {"bzrim",   "r","BZ energy RIM analyzer",0,0,0,0}, 
  {NULL,NULL,NULL,0,0,0,0}
 };
 char *tool="ypp";
 char *tdesc="Y(ambo) P(ost) P(rocessor)";