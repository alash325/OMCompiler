/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-2014, Open Source Modelica Consortium (OSMC),
 * c/o Linköpings universitet, Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF THE BSD NEW LICENSE OR THE
 * GPL VERSION 3 LICENSE OR THE OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
 * RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
 * ACCORDING TO RECIPIENTS CHOICE.
 *
 * The OpenModelica software and the OSMC (Open Source Modelica Consortium)
 * Public License (OSMC-PL) are obtained from OSMC, either from the above
 * address, from the URLs: http://www.openmodelica.org or
 * http://www.ida.liu.se/projects/OpenModelica, and in the OpenModelica
 * distribution. GNU version 3 is obtained from:
 * http://www.gnu.org/copyleft/gpl.html. The New BSD License is obtained from:
 * http://www.opensource.org/licenses/BSD-3-Clause.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, EXCEPT AS
 * EXPRESSLY SET FORTH IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE
 * CONDITIONS OF OSMC-PL.
 *
 */

/*! EvalF.c
 */

#include "../OptimizerData.h"
#include "../OptimizerLocalFunction.h"


/* eval object function
 * author: Vitalij Ruge
 */
Bool evalfF(Index n, Number * vopt, Bool new_x, Number *objValue, void * useData){

  OptData *optData = (OptData*)useData;

  const modelica_boolean la = optData->s.lagrange;
  const modelica_boolean ma = optData->s.mayer;

  long double mayer = 0.0;
  long double lagrange = 0.0;

  if(new_x)
    optData2ModelData(optData, vopt, 1);

  if(la){
    const int nsi = optData->dim.nsi;
    const int np = optData->dim.np;
    const int il = optData->dim.index_lagrange;

    const long double * const b = optData->rk.b;
    const long double * const dt = optData->time.dt;

    modelica_real *** v = optData->v;
    long double erg = 0.0;
    long double erg1 = 0.0;
    long double erg0[np];
    int i,j;

    for(j = 0; j< np; ++j){
      erg0[j] = v[0][j][il];
    }

    for(i = 1; i + 1 < nsi; ++i){
      for(j = 0; j< np; ++j){
        erg0[j] += v[i][j][il];
      }
    }

    for(j = 0; j< np; ++j){
      erg += b[j]*erg0[j];
    }

    i = nsi - 1;
    for(j = 0; j< np; ++j)
      erg1 += b[j]*v[i][j][il];

    lagrange = (erg*dt[0] + erg1*dt[1]);
  }

  if(ma){
    modelica_real *** v = optData->v;
    const int nsi = optData->dim.nsi;
    const int np = optData->dim.np;
    const int im = optData->dim.index_mayer;
    mayer = v[nsi-1][np-1][im];
  }

  *objValue = (Number)(lagrange + mayer);

  return TRUE;
}


/*!
 *  eval derivation (object func)
 *  author: Vitalij Ruge
 **/
Bool evalfDiffF(Index n, double * vopt, Bool new_x, Number *gradF, void * useData){
  OptData *optData = (OptData*)useData;

  const int nv = optData->dim.nv;
  const int nsi = optData->dim.nsi;
  const int np = optData->dim.np;

  const modelica_boolean la = optData->s.lagrange;
  const modelica_boolean ma = optData->s.mayer;

  if(new_x)
    optData2ModelData(optData, vopt, 1);

  if(la){

    const int k = optData->s.derIndex[1];
    int i, j, ii;
    modelica_real * gradL;

    for(i = 0, ii = 0; i < nsi - 1; ++i){
      for(j = 0; j < np; ++j, ii += nv){
        gradL = optData->J[i][j][k];
        memcpy(gradF + ii, gradL, nv*sizeof(modelica_real));
      }
    }

    for(j = 0; j < np; ++j, ii += nv){
      gradL = (j + 1 == np) ? optData->J[i][j][optData->s.derIndex[2]] : optData->J[i][j][k];
      memcpy(gradF + ii, gradL, nv*sizeof(modelica_real));
    }

  }else{
    memset(gradF,0.0,n*sizeof(Number));
  }

  if(ma){
    const int k = optData->s.derIndex[0];
    modelica_real * gradM = optData->J[nsi - 1][np -1][k];
    if(la){
      int i;
      for(i = 0; i < nv; ++i)
        gradF[n-nv + i] += gradM[i];
    }else{
      memcpy(gradF + n - nv, gradM, nv*sizeof(modelica_real));
    }

  }

  return TRUE;
}
