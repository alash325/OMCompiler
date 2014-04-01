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

encapsulated package InlineArrayEquations
" file:        InlineArrayEquations.mo
  package:     InlineArrayEquations
  description: This package contains functions for the optimization module
               inlineArrayEqn.

  RCS: $Id$"

public import BackendDAE;
public import DAE;

protected import BackendDAEUtil;
protected import BackendEquation;
protected import DAEUtil;
protected import Debug;
protected import Expression;
protected import ExpressionDump;
protected import Flags;
protected import List;

// =============================================================================
// inline arrayeqns stuff
//
// public functions:
//   - inlineArrayEqn
//   - getScalarArrayEqns
// =============================================================================

public function inlineArrayEqn "
  Optimization module: inlineArrayEqn
  This module expands all array equations to scalar equations."
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outDAE, _) := BackendDAEUtil.mapEqSystemAndFold(inDAE, inlineArrayEqn1, false);
end inlineArrayEqn;

protected function inlineArrayEqn1
  input BackendDAE.EqSystem inEqSystem;
  input tuple<BackendDAE.Shared, Boolean /*modified?*/> inSharedOptimized;
  output BackendDAE.EqSystem outEqSystem;
  output tuple<BackendDAE.Shared, Boolean /*modified?*/> outSharedOptimized;
algorithm
  (outEqSystem, outSharedOptimized) := matchcontinue(inEqSystem, inSharedOptimized)
    local
      BackendDAE.Variables orderedVars;
      BackendDAE.EquationArray orderedEqs;
      BackendDAE.Shared shared;
      list<BackendDAE.Equation> eqnLst;
      BackendDAE.StateSets stateSets;
      
    case (BackendDAE.EQSYSTEM(orderedVars=orderedVars, orderedEqs=orderedEqs, stateSets=stateSets), (shared, _)) equation
      eqnLst = BackendEquation.equationList(orderedEqs);
      (eqnLst, true) = getScalarArrayEqns(eqnLst);
      orderedEqs = BackendEquation.listEquation(eqnLst);
    then (BackendDAE.EQSYSTEM(orderedVars, orderedEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(), stateSets), (shared, true));
      
    else
    then (inEqSystem, inSharedOptimized);
  end matchcontinue;
end inlineArrayEqn1;

public function getScalarArrayEqns "
  Public wrapper function of getScalarArrayEqns0."
  input list<BackendDAE.Equation> inEqnLst;
  output list<BackendDAE.Equation> outEqnLst;
  output Boolean outFound;
algorithm
  (outEqnLst, outFound) := getScalarArrayEqns0(inEqnLst, {}, false);
end getScalarArrayEqns;

protected function getScalarArrayEqns0 "
  This functions does the actual work for the optimization module 'inlineArrayEqn'.
  This function is also called from the index reduction."
  input list<BackendDAE.Equation> inEqnLst;
  input list<BackendDAE.Equation> inAccEqnLst "initial call with '{}'";
  input Boolean inFound "initial call with 'false'";
  output list<BackendDAE.Equation> outEqnLst;
  output Boolean outFound;
algorithm
  (outEqnLst, outFound) := match(inEqnLst, inAccEqnLst, inFound)
    local
      BackendDAE.Equation eqn;
      list<BackendDAE.Equation> eqns, eqns1;
      Boolean b;
      
    case ({}, _, _)
    then (listReverse(inAccEqnLst), inFound);
    
    case (eqn::eqns, _, _) equation
      (eqns1, b) = getScalarArrayEqns1(eqn, inAccEqnLst);
      (eqns1, b) = getScalarArrayEqns0(eqns, eqns1, b or inFound);
    then (eqns1, b);
  end match;
end getScalarArrayEqns0;

protected function getScalarArrayEqns1
  input  BackendDAE.Equation inEqn;
  input list<BackendDAE.Equation> inAccEqnLst;
  output list<BackendDAE.Equation> outEqnLst;
  output Boolean outFound;
algorithm
  (outEqnLst, outFound) := matchcontinue(inEqn, inAccEqnLst)
    local
      DAE.ElementSource source;
      DAE.Exp lhs, rhs, e1_1, e2_1;
      list<DAE.Exp> ea1, ea2;
      list<BackendDAE.Equation> eqns;
      Boolean differentiated;
    
    case (BackendDAE.ARRAY_EQUATION(left=lhs, right=rhs, source=source, differentiated=differentiated), _) equation
      true = Expression.isArray(lhs) or Expression.isMatrix(lhs);
      true = Expression.isArray(rhs) or Expression.isMatrix(rhs);
      ea1 = Expression.flattenArrayExpToList(lhs);
      ea2 = Expression.flattenArrayExpToList(rhs);
      ((_, eqns)) = List.threadFold3(ea1, ea2, generateScalarArrayEqns2, source, differentiated, DAE.EQUALITY_EXPS(lhs, rhs), (1, inAccEqnLst));
    then (eqns, true);
    
    case (BackendDAE.ARRAY_EQUATION(left=lhs as DAE.CREF(componentRef=_), right=rhs, source=source, differentiated=differentiated), _) equation
      true = Expression.isArray(rhs) or Expression.isMatrix(rhs);
      ((e1_1, (_, _))) = BackendDAEUtil.extendArrExp((lhs, (NONE(), false)));
      ea1 = Expression.flattenArrayExpToList(e1_1);
      ea2 = Expression.flattenArrayExpToList(rhs);
      ((_, eqns)) = List.threadFold3(ea1, ea2, generateScalarArrayEqns2, source, differentiated, DAE.EQUALITY_EXPS(lhs, rhs), (1, inAccEqnLst));
    then (eqns, true);
      
    case (BackendDAE.ARRAY_EQUATION(left=lhs, right=rhs as DAE.CREF(componentRef=_), source=source, differentiated=differentiated), _) equation
      true = Expression.isArray(lhs) or Expression.isMatrix(lhs);
      ((e2_1, (_, _))) = BackendDAEUtil.extendArrExp((rhs,(NONE(),false)));
      ea1 = Expression.flattenArrayExpToList(lhs);
      ea2 = Expression.flattenArrayExpToList(e2_1);
      ((_, eqns)) = List.threadFold3(ea1, ea2, generateScalarArrayEqns2, source, differentiated, DAE.EQUALITY_EXPS(lhs, rhs), (1, inAccEqnLst));
    then (eqns,true);
      
    case (BackendDAE.ARRAY_EQUATION(left=lhs as DAE.CREF(componentRef=_),right=rhs as DAE.CREF(componentRef=_), source=source, differentiated=differentiated), _) equation
      ((e1_1, (_, _))) = BackendDAEUtil.extendArrExp((lhs, (NONE(), false)));
      ((e2_1, (_, _))) = BackendDAEUtil.extendArrExp((rhs, (NONE(), false)));
      ea1 = Expression.flattenArrayExpToList(e1_1);
      ea2 = Expression.flattenArrayExpToList(e2_1);
      ((_, eqns)) = List.threadFold3(ea1, ea2, generateScalarArrayEqns2, source, differentiated, DAE.EQUALITY_EXPS(lhs, rhs), (1, inAccEqnLst));
    then (eqns, true);
      
    case (BackendDAE.COMPLEX_EQUATION(left=lhs, right=rhs, source=source, differentiated=differentiated), _) equation
      ea1 = Expression.splitRecord(lhs,Expression.typeof(lhs));
      ea2 = Expression.splitRecord(rhs,Expression.typeof(rhs));
      ((_, eqns)) = List.threadFold3(ea1, ea2, generateScalarArrayEqns2, source, differentiated, DAE.EQUALITY_EXPS(lhs, rhs), (1, inAccEqnLst));
    then (eqns, true);
        
    case (_, _)
    then (inEqn::inAccEqnLst, false);
  end matchcontinue;
end getScalarArrayEqns1;

protected function generateScalarArrayEqns2
  input DAE.Exp inExp1;
  input DAE.Exp inExp2;
  input DAE.ElementSource inSource;
  input Boolean diffed;
  input DAE.EquationExp eqExp "original expressions; for the symbolic trace";
  input tuple<Integer /* current index; for the symbolic trace */, list<BackendDAE.Equation>> iEqns;
  output tuple<Integer, list<BackendDAE.Equation>> oEqns;
algorithm
  oEqns := matchcontinue(inExp1,inExp2,inSource,diffed,eqExp,iEqns)
    local
      DAE.Type tp;
      Integer size, i;
      DAE.Dimensions dims;
      list<Integer> ds;
      Boolean b1, b2;
      list<BackendDAE.Equation> eqns;
      DAE.ElementSource source;
      
    // complex types to complex equations
    case (_, _, _, _, _, (i, eqns)) equation
      tp = Expression.typeof(inExp1);
      true = DAEUtil.expTypeComplex(tp);
      size = Expression.sizeOf(tp);
      source = DAEUtil.addSymbolicTransformation(inSource, DAE.OP_SCALARIZE(eqExp, i, DAE.EQUALITY_EXPS(inExp1, inExp2)));
    then ((i+1, BackendDAE.COMPLEX_EQUATION(size, inExp1, inExp2, source, diffed)::eqns));

    // array types to array equations
    case (_, _, _, _, _, (i, eqns)) equation
      tp = Expression.typeof(inExp1);
      true = DAEUtil.expTypeArray(tp);
      dims = Expression.arrayDimension(tp);
      ds = Expression.dimensionsSizes(dims);
      source = DAEUtil.addSymbolicTransformation(inSource, DAE.OP_SCALARIZE(eqExp, i, DAE.EQUALITY_EXPS(inExp1, inExp2)));
    then ((i+1, BackendDAE.ARRAY_EQUATION(ds, inExp1, inExp2, source, diffed)::eqns));
        
    // other types
    case (_, _, _, _, _, (i, eqns)) equation
      tp = Expression.typeof(inExp1);
      b1 = DAEUtil.expTypeComplex(tp);
      b2 = DAEUtil.expTypeArray(tp);
      false = b1 or b2;
      source = DAEUtil.addSymbolicTransformation(inSource, DAE.OP_SCALARIZE(eqExp, i, DAE.EQUALITY_EXPS(inExp1, inExp2)));
    then ((i+1, BackendDAE.EQUATION(inExp1, inExp2, source, diffed)::eqns));
        
    else equation
      // show only on failtrace!
      true = Flags.isSet(Flags.FAILTRACE);
      Debug.traceln("- InlineArrayEquations.generateScalarArrayEqns2 failed on: " +& ExpressionDump.printExpStr(inExp1) +& " = " +& ExpressionDump.printExpStr(inExp2) +& "\n");
    then fail();
  end matchcontinue;
end generateScalarArrayEqns2;

end InlineArrayEquations;