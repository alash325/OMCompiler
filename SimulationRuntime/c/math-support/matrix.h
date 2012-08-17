/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-CurrentYear, Linköping University,
 * Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3
 * AND THIS OSMC PUBLIC LICENSE (OSMC-PL).
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES RECIPIENT'S
 * ACCEPTANCE OF THE OSMC PUBLIC LICENSE.
 *
 * The OpenModelica software and the Open Source Modelica
 * Consortium (OSMC) Public License (OSMC-PL) are obtained
 * from Linköping University, either from the above address,
 * from the URLs: http://www.ida.liu.se/projects/OpenModelica or
 * http://www.openmodelica.org, and in the OpenModelica distribution.
 * GNU version 3 is obtained from: http://www.gnu.org/copyleft/gpl.html.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of  MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS
 * OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */

#ifndef _MATRIX_H_
#define _MATRIX_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "blaswrap.h"
#include "f2c.h"
#ifdef VOID
#undef VOID
#endif

extern
int _omc_dgesv_(integer *n, integer *nrhs, doublereal *a, integer
     *lda, integer *ipiv, doublereal *b, integer *ldb, integer *info);

extern
void _omc_hybrd_(void (*) (int*, double *, double*, int*, void* data),
      int* n, double* x,double* fvec,double* xtol,
      int* maxfev, int* ml,int* mu,double* epsfcn,
      double* diag,int* mode, double* factor,
      int* nprint,int* info,int* nfev,double* fjac,
      int* ldfjac,double* r, int* lr, double* qtf,
      double* wa1,double* wa2,double* wa3,double* wa4, void* userdata);

extern
void * _omc_hybrj_(void(*) (int*, double*, double*, double *, int*, int*, void* data),
      int *n,double*x,double*fvec,double*fjac,int *ldfjac,double*xtol,int* maxfev,
      double* diag,int *mode,double*factor,int *nprint,int*info,int*nfev,int*njev,
      double* r,int *lr,double*qtf,double*wa1,double*wa2,
        double* wa3,double* wa4, void* userdata);

#ifdef __cplusplus
}
#endif

#define print_matrix(A,d1,d2) do {\
  int r = 0, c = 0;\
  printf("{{"); \
  for(r = 0; r < d1; r++) {\
    for (c = 0; c < d2; c++) {\
      printf("%2.3f",A[r + d1 * c]);\
      if (c != d2-1) printf(",");\
    }\
    if(r != d1-1) printf("},{");\
  }\
  printf("}}\n"); \
} while(0)
#define print_vector(b,d1) do {\
  int i = 0; \
  printf("{");\
  for(i = 0;i < d1; i++) { \
    printf("%2.3f", b[i]); \
    if (i != d1-1) printf(",");\
  } \
  printf("}\n"); \
} while(0)

#define solve_nonlinear_system(residual, no, userdata) do { \
   int giveUp = 0; \
   int retries = 0; \
   int retries2 = 0; \
   int retries3 = 0; \
   int i; \
   for (i = 0; i < n; i++) { nls_diagSave[i] = nls_diag[i]; }; \
   if (DEBUG_FLAG(LOG_NONLIN_SYS)){ \
     INFO2("Start solving Non-Linear System %s at time %f", no.name, data->localData[0]->timeValue); \
   } \
   while(!giveUp) { \
     giveUp = 1; \
     _omc_hybrd_(residual,&n, nls_x,nls_fvec,&xtol,&maxfev,&ml,&mu,&epsfcn, \
          nls_diag,&mode,&factor,&nprint,&info,&nfev,nls_fjac,&ldfjac, \
        nls_r,&lr,nls_qtf,nls_wa1,nls_wa2,nls_wa3,nls_wa4, userdata); \
      if (info == 0) {\
          printErrorEqSyst(IMPROPER_INPUT, no, data->localData[0]->timeValue); \
          data->found_solution = -1; \
      }\
      if (info == 1){ \
        if (DEBUG_FLAG(LOG_NONLIN_SYS)) { \
          INFO_AL("### System solved! ###"); \
          INFO_AL2("\tSolution with %d retries and %d restarts.",retries, retries2); \
          INFO_AL2("\tinfo = %d\tnfunc = %d",info, nfev); \
          if (DEBUG_FLAG(LOG_DEBUG)) { \
            for (i = 0; i < n; i++) { \
              INFO_AL7("%d. scale-factor[%d] = %f\tresidual[%d] = %f\tx[%d] = %f",i,i,nls_diag[i],i,nls_fvec[i],i,nls_x[i]); \
            } \
          } \
        } \
      } \
      if ((info == 4 || info == 5) && retries < 3) { /* first try to decrease factor*/ \
        retries++;  giveUp = 0; \
        factor = factor / 10.0; \
        if (DEBUG_FLAG(LOG_NONLIN_SYS))  \
          INFO_AL1(" - iteration making no progress:\tdecrease factor to %f",factor); \
      } else if ((info == 4 || info == 5) && retries < 5) { /* Then, try with different starting point*/  \
        for (i = 0; i < n; i++) { nls_x[i] += 0.1; }; \
        retries++;  giveUp=0; \
        if (DEBUG_FLAG(LOG_NONLIN_SYS)) \
          INFO_AL(" - iteration making no progress:\tvary initial point by +1%%"); \
      } else if ((info == 4 || info == 5) && retries < 7) {   \
         for (i = 0; i < n; i++) { nls_x[i] = nls_xEx[i]*1.01; }; \
         retries++; giveUp=0; \
         if (DEBUG_FLAG(LOG_NONLIN_SYS)) \
           INFO_AL(" - iteration making no progress:\tvary initial point by adding 1%%"); \
      } else if ((info == 4 || info == 5) && retries < 9) { \
        for (i = 0; i < n; i++) { nls_x[i] = nls_xEx[i] * 0.99; }; \
        retries++; giveUp=0; \
        if (DEBUG_FLAG(LOG_NONLIN_SYS)) \
          INFO_AL(" - iteration making no progress:\tvary initial point by %%"); \
      } else if ((info == 4 || info == 5) && retries2 < 1) { /*Then try with old values (instead of extrapolating )*/ \
        factor = initial_factor; retries = 0; retries2++; giveUp = 0; \
        for (i = 0; i < n; i++) { nls_x[i] = nls_xold[i]; } \
        if (DEBUG_FLAG(LOG_NONLIN_SYS)) \
          INFO_AL(" - iteration making no progress:\tuse old values instead extrapolated"); \
      } else if ((info == 4 || info == 5) && retries3 < 1) { \
         for (i = 0; i < n; i++) { nls_diag[i] = nls_diagSave[i];} \
         factor = initial_factor; retries = 0; retries2 = 0; mode = 2; retries3++; giveUp = 0;\
         if (DEBUG_FLAG(LOG_NONLIN_SYS)) \
           INFO_AL(" - iteration making no progress:\tchange scaling factors"); \
     } else if ((info == 4 || info == 5) && retries3 < 2) { \
        for (i = 0; i < n; i++) { nls_x[i] = nls_xEx[i]; nls_diag[i] = fmax(1e-2,fabs(nls_xEx[i]));} \
        factor = initial_factor; retries = 0; retries2 = 0; mode = 1; retries3++; giveUp = 0;\
        if (DEBUG_FLAG(LOG_NONLIN_SYS)) \
          INFO_AL(" - iteration making no progress:\tchange scaling factors"); \
      } else if ((info == 4 || info == 5) && retries3 < 3) {  \
        for (i = 0; i < n; i++) { nls_x[i] = nls_xEx[i]; nls_diag[i] = 1.0; } \
        factor = initial_factor; retries = 0; retries2 = 0; retries3++; mode = 2; giveUp = 0;\
        if (DEBUG_FLAG(LOG_NONLIN_SYS)) \
        INFO_AL(" - iteration making no progress:\tremove scaling factor at all!"); \
      } else if (info >= 2 && info <= 5) { \
        data->found_solution = -1; \
        modelErrorCode=ERROR_NONLINSYS; \
        printErrorEqSyst(ERROR_AT_TIME, no, data->localData[0]->timeValue); \
        if (DEBUG_FLAG(LOG_DEBUG)) { \
          for (i = 0; i < n; i++) { \
             INFO_AL7("\t%d. scale-factor[%d] = %f\tresidual[%d] = %f\tx[%d] = %f",i,i,nls_diag[i],i,nls_fvec[i],i,nls_x[i]); \
          } \
        } \
      }\
   }\
} while(0) /* (no trailing ;)*/

#define solve_nonlinear_system_analytic_jac(residual, no, userdata) do { \
   int giveUp = 0; \
   int retries = 0; \
   while(!giveUp) { \
     giveUp = 1; \
     _omc_hybrj_(residual,&n, nls_x,nls_fvec,nls_fjac,&ldfjac,&xtol,&maxfev,\
          nls_diag,&mode,&factor,&nprint,&info,&nfev,&njev, \
        nls_r,&lr,nls_qtf,nls_wa1,nls_wa2,nls_wa3,nls_wa4, userdata); \
      if (info == 0) { \
          printErrorEqSyst(IMPROPER_INPUT, no, data->localData[0]->timeValue); \
      } \
      if ((info == 4 || info == 5) && retries < 3) { /* First try to decrease factor*/ \
        retries++; giveUp = 0; \
        factor = factor / 10.0; \
           if (sim_verbose)  \
          printErrorEqSyst(NO_PROGRESS_FACTOR, no, factor); \
      } else if ((info == 4 || info == 5) && retries < 5) { /* Secondly, try with different starting point*/  \
        int i = 0; \
        for (i = 0; i < n; i++) { nls_x[i] += 0.1; }; \
        retries++; giveUp=0; \
        if (sim_verbose) \
            printErrorEqSyst(NO_PROGRESS_START_POINT, no, 1e-6); \
        } \
        else if (info >= 2 && info <= 5) { \
          modelErrorCode=ERROR_NONLINSYS; \
          printErrorEqSyst(no, data->localData[0]->timeValue); \
        } \
     }\
} while(0) /* (no trailing ;)*/

/* Matrixes using column major order (as in Fortran) */
#define set_matrix_elt(A,r,c,n_rows,value) A[r + n_rows * c] = value
#define get_matrix_elt(A,r,c,n_rows) A[r + n_rows * c]

/* Vectors */
#define set_vector_elt(v,i,value) v[i] = value
#define get_vector_elt(v,i) v[i]

#define solve_linear_equation_system(A,b,size,id) do { integer n = size; \
integer nrhs = 1; /* number of righthand sides*/\
integer lda = n /* Leading dimension of A */; integer ldb=n; /* Leading dimension of b*/\
integer * ipiv = (integer*) calloc(n,sizeof(integer)); /* Pivott indices */ \
integer info = 0; /* output */ \
assert(ipiv != 0); \
_omc_dgesv_(&n,&nrhs,&A[0],&lda,ipiv,&b[0],&ldb,&info); \
 if (info < 0) { \
   DEBUG_INFO3(LOG_NONLIN_SYS,"Error solving linear system of equations (no. %d) at time %f. Argument %d illegal.\n",id,data->localData[0]->timeValue,info); \
   data->found_solution = -1; \
 } \
 else if (info > 0) { \
   DEBUG_INFO2(LOG_NONLIN_SYS,"Error solving linear system of equations (no. %d) at time %f, system is singular.\n",id,data->localData[0]->timeValue); \
   data->found_solution = -1; \
 } \
free(ipiv); \
} while (0) /* (no trailing ; ) */

#define start_nonlinear_system(size) { double nls_x[size]; \
double nls_xEx[size] = {0}; \
double nls_xold[size] = {0}; \
double nls_fvec[size] = {0}; \
double nls_diag[size] = {0}; \
double nls_diagSave[size] = {0}; \
double nls_r[(size*(size + 1) / 2)] = {0}; \
double nls_qtf[size] = {0}; \
double nls_wa1[size] = {0}; \
double nls_wa2[size] = {0}; \
double nls_wa3[size] = {0}; \
double nls_wa4[size] = {0}; \
double xtol =  1e-12; \
double epsfcn = 1e-12; \
int maxfev = size*10000; \
int n = size; \
int ml = size - 1; \
int mu = size - 1; \
int mode = 1; \
int info = 0, nfev = 0, njev = 0; \
double factor = 100.0; \
double initial_factor = 100.0; \
int nprint = 0; \
int lr = (size*(size + 1)) / 2; \
int ldfjac = size; \
double nls_fjac[size*size] = {0};

#define start_nonlinear_system_analytic_jac(size) { double nls_x[size]; \
double nls_fvec[size] = {0}; \
double nls_fjac[size*size] = {0}; \
double nls_diag[size] = {0}; \
double nls_r[(size*(size + 1) / 2)] = {0}; \
double nls_qtf[size] = {0}; \
double nls_wa1[size] = {0}; \
double nls_wa2[size] = {0}; \
double nls_wa3[size] = {0}; \
double nls_wa4[size] = {0}; \
double xtol = 1e-12; \
double epsfcn = 1e-12; \
int maxfev = 8000; \
int n = size; \
int ml = size - 1; \
int mu = size - 1; \
int mode = 1; \
int info = 0, nfev = 0, njev = 0; \
double factor = 100.0; \
int nprint = 0; \
int lr = (size*(size + 1)) / 2; \
int ldfjac = size;
#define end_nonlinear_system() } do {} while(0)

#define extraPolate(v,old1,old2) (data->localData[1]->timeValue == data->localData[2]->timeValue ) ? v: \
(((old1)-(old2))/(data->localData[1]->timeValue-data->localData[2]->timeValue)*data->localData[0]->timeValue \
+(data->localData[1]->timeValue*(old2)-data->localData[2]->timeValue*(old1))/ \
(data->localData[1]->timeValue-data->localData[2]->timeValue))

#define mixed_equation_system(size) do { \
    int cur_value_indx = 0; \
    data->found_solution = 0; \
    do { \
        double discrete_loc[size] = {0}; \
        double discrete_loc2[size] = {0};

#define mixed_equation_system_end(size) } while (!data->found_solution); \
 } while(0)

#define check_discrete_values(size,numValues) \
do { \
  int i = 0; \
  if (data->found_solution == -1) { \
  /*system of equations failed */ \
      data->found_solution = 0; \
  } else { \
      data->found_solution = 1; \
      for (i = 0; i < size; i++) { \
          if (fabs((discrete_loc[i] - discrete_loc2[i])) > 1e-12) {\
          data->found_solution=0;\
              break;\
          }\
      }\
  }\
  if (!data->found_solution ) { \
      cur_value_indx++; \
      if (cur_value_indx >= numValues/size) { \
          data->found_solution = -1; \
      } else {\
      /* try next set of values*/ \
          for (i = 0; i < size; i++) { \
              *loc_ptrs[i] = (modelica_boolean)values[cur_value_indx * size + i];  \
          } \
      } \
  } \
  /* we found a solution*/ \
  if (data->found_solution && DEBUG_FLAG(LOG_NONLIN_SYS)){ \
      int i = 0; \
      printf("Result of mixed system discrete variables:\n"); \
      for (i = 0; i < size; i++) { \
        int ix = (loc_ptrs[i]-data->localData[0]->booleanVars); \
        const char *__name = data->modelData.booleanVarsData[ix].info.name; \
        printf("%s = %d  pre(%s)= %d\n",__name, *loc_ptrs[i], __name, data->simulationInfo.booleanVarsPre[ix]); \
      } \
      fflush(NULL); \
  } \
} while(0)

#endif
