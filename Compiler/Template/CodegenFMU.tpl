// This file defines templates for transforming Modelica/MetaModelica code to FMU 
// code. They are used in the code generator phase of the compiler to write
// target code.
//
// There are one root template intended to be called from the code generator:
// translateModel. These template do not return any
// result but instead write the result to files. All other templates return
// text and are used by the root templates (most of them indirectly).
//
// To future maintainers of this file:
//
// - A line like this
//     # var = "" /*BUFD*/
//   declares a text buffer that you can later append text to. It can also be
//   passed to other templates that in turn can append text to it. In the new
//   version of Susan it should be written like this instead:
//     let &var = buffer ""
//
// - A line like this
//     ..., Text var /*BUFP*/, ...
//   declares that a template takes a text buffer as input parameter. In the
//   new version of Susan it should be written like this instead:
//     ..., Text &var, ...
//
// - A line like this:
//     ..., var /*BUFC*/, ...
//   passes a text buffer to a template. In the new version of Susan it should
//   be written like this instead:
//     ..., &var, ...
//
// - Style guidelines:
//
//   - Try (hard) to limit each row to 80 characters
//
//   - Code for a template should be indented with 2 spaces
//
//     - Exception to this rule is if you have only a single case, then that
//       single case can be written using no indentation
//
//       This single case can be seen as a clarification of the input to the
//       template
//
//   - Code after a case should be indented with 2 spaces if not written on the
//     same line

package CodegenFMU

import interface SimCodeTV;
import CodegenUtil.*;
import CodegenC.*; //unqualified import, no need the CodegenC is optional when calling a template; or mandatory when the same named template exists in this package (name hiding) 


template translateModel(SimCode simCode) 
 "Generates C code and Makefile for compiling a FMU of a
  Modelica model."
::=
match simCode
case SIMCODE(modelInfo=modelInfo as MODELINFO(__)) then
  let guid = getUUIDStr()
  let()= textFile(simulationFunctionsHeaderFile(fileNamePrefix, modelInfo.functions, recordDecls), '<%fileNamePrefix%>_functions.h')
  let()= textFile(simulationFunctionsFile(fileNamePrefix, modelInfo.functions, literals), '<%fileNamePrefix%>_functions.c')
  let()= textFile(recordsFile(fileNamePrefix, recordDecls), '<%fileNamePrefix%>_records.c')
  let()= textFile(simulationHeaderFile(simCode,guid), '_<%fileNamePrefix%>.h')
  let()= textFile(simulationFile(simCode,guid), '<%fileNamePrefix%>.c')
  let()= textFile(fmumodel_identifierFile(simCode,guid), '<%fileNamePrefix%>_FMU.c')
  let()= textFile(fmuModelDescriptionFile(simCode,guid), 'modelDescription.xml')
  let()= textFile(fmudeffile(simCode), '<%fileNamePrefix%>.def')
  let()= textFile(fmuMakefile(simCode), '<%fileNamePrefix%>_FMU.makefile')
  "" // Return empty result since result written to files directly
end translateModel;


template fmuModelDescriptionFile(SimCode simCode, String guid)
 "Generates code for ModelDescription file for FMU target."
::=
match simCode
case SIMCODE(__) then
  <<
  <?xml version="1.0" encoding="UTF-8"?>
  <%fmiModelDescription(simCode,guid)%>
  
  >>
end fmuModelDescriptionFile;

template fmiModelDescription(SimCode simCode, String guid)
 "Generates code for ModelDescription file for FMU target."
::=
//  <%UnitDefinitions(simCode)%>
//  <%TypeDefinitions(simCode)%>
//  <%VendorAnnotations(simCode)%>
match simCode
case SIMCODE(__) then
  <<
  <fmiModelDescription 
    <%fmiModelDescriptionAttributes(simCode,guid)%>>
    <%DefaultExperiment(simulationSettingsOpt)%>
    <%ModelVariables(modelInfo)%>  
  </fmiModelDescription>  
  >>
end fmiModelDescription;

template fmiModelDescriptionAttributes(SimCode simCode, String guid)
 "Generates code for ModelDescription file for FMU target."
::=
match simCode
case SIMCODE(modelInfo = MODELINFO(varInfo = vi as VARINFO(__), vars = SIMVARS(stateVars = listStates))) then
  let fmiVersion = '1.0' 
  let modelName = dotPath(modelInfo.name)
  let modelIdentifier = System.stringReplace(fileNamePrefix,".", "_")
  let description = ''
  let author = ''
  let version= '' 
  let generationTool= 'OpenModelica Compiler <%getVersionNr()%>'
  let generationDateAndTime = xsdateTime(getCurrentDateTime())
  let variableNamingConvention = 'structured'
  let numberOfContinuousStates = if intEq(vi.numStateVars,1) then statesnumwithDummy(listStates) else  vi.numStateVars
  let numberOfEventIndicators = vi.numZeroCrossings 
//  description="<%description%>" 
//    author="<%author%>" 
//    version="<%version%>" 
  << 
  fmiVersion="<%fmiVersion%>" 
  modelName="<%modelName%>"
  modelIdentifier="<%modelIdentifier%>" 
  guid="{<%guid%>}" 
  generationTool="<%generationTool%>" 
  generationDateAndTime="<%generationDateAndTime%>"
  variableNamingConvention="<%variableNamingConvention%>" 
  numberOfContinuousStates="<%numberOfContinuousStates%>" 
  numberOfEventIndicators="<%numberOfEventIndicators%>" 
  >>
end fmiModelDescriptionAttributes;

template statesnumwithDummy(list<SimVar> vars)
" return number of states without dummy vars"
::=
 (vars |> var =>  match var case SIMVAR(__) then if stringEq(crefStr(name),"$dummy") then '0' else '1' ;separator="\n")
end statesnumwithDummy;

template xsdateTime(DateTime dt)
 "YYYY-MM-DDThh:mm:ssZ"
::=
  match dt
  case DATETIME(__) then '<%year%>-<%twodigit(mon)%>-<%twodigit(mday)%>T<%twodigit(hour)%>:<%twodigit(min)%>:<%twodigit(sec)%>Z'
end xsdateTime;

template UnitDefinitions(SimCode simCode)
 "Generates code for UnitDefinitions file for FMU target."
::=
match simCode
case SIMCODE(__) then
  <<
  <UnitDefinitions>
  </UnitDefinitions>  
  >>
end UnitDefinitions;

template TypeDefinitions(SimCode simCode)
 "Generates code for TypeDefinitions file for FMU target."
::=
match simCode
case SIMCODE(__) then
  <<
  <TypeDefinitions>
  </TypeDefinitions>  
  >>
end TypeDefinitions;

template DefaultExperiment(Option<SimulationSettings> simulationSettingsOpt)
 "Generates code for DefaultExperiment file for FMU target."
::=
match simulationSettingsOpt
  case SOME(v) then 
    <<
    <DefaultExperiment <%DefaultExperimentAttribute(v)%>/>
      >>
end DefaultExperiment;

template DefaultExperimentAttribute(SimulationSettings simulationSettings)
 "Generates code for DefaultExperiment Attribute file for FMU target."
::=
match simulationSettings
  case SIMULATION_SETTINGS(__) then 
    <<
    startTime="<%startTime%>" stopTime="<%stopTime%>" tolerance="<%tolerance%>"
      >>
end DefaultExperimentAttribute;

template VendorAnnotations(SimCode simCode)
 "Generates code for VendorAnnotations file for FMU target."
::=
match simCode
case SIMCODE(__) then
  <<
  <VendorAnnotations>
  </VendorAnnotations>  
  >>
end VendorAnnotations;

template ModelVariables(ModelInfo modelInfo)
 "Generates code for ModelVariables file for FMU target."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  <<
  <ModelVariables>
  <%System.tmpTickReset(0)%>
  <%vars.stateVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>  
  <%vars.derivativeVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%vars.algVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%vars.paramVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%vars.aliasVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%System.tmpTickReset(0)%>
  <%vars.intAlgVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%vars.intParamVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%vars.intAliasVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%System.tmpTickReset(0)%>
  <%vars.boolAlgVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%vars.boolParamVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>  
  <%vars.boolAliasVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>  
  <%System.tmpTickReset(0)%>
  <%vars.stringAlgVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%>
  <%vars.stringParamVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%> 
  <%vars.stringAliasVars |> var =>
    ScalarVariable(var)
  ;separator="\n"%> 
  <%System.tmpTickReset(0)%>
  <%externalFunctions(modelInfo)%>    
  </ModelVariables>  
  >>
end ModelVariables;

template ScalarVariable(SimVar simVar)
 "Generates code for ScalarVariable file for FMU target."
::=
match simVar
case SIMVAR(__) then
  if stringEq(crefStr(name),"$dummy") then 
  <<>>
  else if stringEq(crefStr(name),"der($dummy)") then
  <<>>
  else
  <<
  <ScalarVariable 
    <%ScalarVariableAttribute(simVar)%>>
    <%ScalarVariableType(type_,unit,displayUnit,initialValue,isFixed)%>
  </ScalarVariable>  
  >>
end ScalarVariable;

template ScalarVariableAttribute(SimVar simVar)
 "Generates code for ScalarVariable Attribute file for FMU target."
::=
match simVar
  case SIMVAR(__) then
  let valueReference = '<%System.tmpTick()%>'
  let variability = getVariablity(varKind)
  let description = if comment then 'description="<%Util.escapeModelicaStringToXmlString(comment)%>"' 
  let alias = getAliasVar(aliasvar)
  let caus = getCausality(causality)
  <<
  name="<%System.stringReplace(crefStr(name),"$", "_D_")%>" 
  valueReference="<%valueReference%>" 
  <%description%>
  variability="<%variability%>" 
  causality="<%caus%>" 
  alias="<%alias%>"
  >>  
end ScalarVariableAttribute;

template getCausality(Causality c)
 "Returns the Causality Attribute of ScalarVariable."
::=
match c
  case NONECAUS(__) then "none"
  case INTERNAL(__) then "internal"
  case OUTPUT(__) then "output"
  case INPUT(__) then "input"
end getCausality;

template getVariablity(VarKind varKind)
 "Returns the variablity Attribute of ScalarVariable."
::=
match varKind
  case DISCRETE(__) then "discrete"
  case PARAM(__) then "parameter"
  case CONST(__) then "constant"
  else "continuous"
end getVariablity;

template getAliasVar(AliasVariable aliasvar)
 "Returns the alias Attribute of ScalarVariable."
::=
match aliasvar
  case NOALIAS(__) then "noAlias"
  case ALIAS(__) then "alias"
  case NEGATEDALIAS(__) then "negatedAlias"
  else "noAlias"
end getAliasVar;

template ScalarVariableType(DAE.Type type_, String unit, String displayUnit, Option<DAE.Exp> initialValue, Boolean isFixed)
 "Generates code for ScalarVariable Type file for FMU target."
::=
match type_
  case T_INTEGER(__) then '<Integer/>' 
  case T_REAL(__) then '<Real <%ScalarVariableTypeCommonAttribute(initialValue,isFixed)%> <%ScalarVariableTypeRealAttribute(unit,displayUnit)%>/>' 
  case T_BOOL(__) then '<Boolean/>' 
  case T_STRING(__) then '<String/>' 
  case T_ENUMERATION(__) then '<Real/>' 
  else 'UNKOWN_TYPE'
end ScalarVariableType;

template ScalarVariableTypeCommonAttribute(Option<DAE.Exp> initialValue, Boolean isFixed)
 "Generates code for ScalarVariable Type file for FMU target."
::=
match initialValue
  case SOME(exp) then 'start="<%initVal(exp)%>" fixed="<%isFixed%>"'
end ScalarVariableTypeCommonAttribute;

template ScalarVariableTypeRealAttribute(String unit, String displayUnit)
 "Generates code for ScalarVariable Type Real file for FMU target."
::=
  let unit_ = if unit then 'unit="<%unit%>"'   
  let displayUnit_ = if displayUnit then 'displayUnit="<%displayUnit%>"'   
  <<
  <%unit_%> <%displayUnit_%>
  >>
end ScalarVariableTypeRealAttribute;

template externalFunctions(ModelInfo modelInfo)
 "Generates external function definitions."
::=  
match modelInfo
case MODELINFO(__) then
  (functions |> fn => externalFunction(fn) ; separator="\n")
end externalFunctions;

template externalFunction(Function fn)
 "Generates external function definitions."
::=
  match fn
    case EXTERNAL_FUNCTION(dynamicLoad=true) then
      let fname = extFunctionName(extName, language)
      <<
      <ExternalFunction
        name="<%fname%>"
        valueReference="<%System.tmpTick()%>"/> 
      >> 
end externalFunction;


template fmumodel_identifierFile(SimCode simCode, String guid)
 "Generates code for ModelDescription file for FMU target."
::=
match simCode
case SIMCODE(__) then
  <<
  
  // define class name and unique id
  #define MODEL_IDENTIFIER <%System.stringReplace(fileNamePrefix,".", "_")%>
  #define MODEL_GUID "{<%guid%>}"

  // include fmu header files, typedefs and macros
  #include <stdio.h>
  #include <string.h>
  #include <assert.h>  
  #include "openmodelica.h"
  #include "openmodelica_func.h"
  #include "simulation_data.h"  
  #include "omc_error.h"
  #include "fmiModelTypes.h"
  #include "fmiModelFunctions.h"
  #include "<%fileNamePrefix%>_functions.h"
  #include "initialization.h"
  #include "events.h"
  #include "fmu_model_interface.h"  

  #ifdef __cplusplus
  extern "C" {
  #endif

  void setStartValues(ModelInstance *comp);
  void setDefaultStartValues(ModelInstance *comp);
  void eventUpdate(ModelInstance* comp, fmiEventInfo* eventInfo);
  fmiReal getReal(ModelInstance* comp, const fmiValueReference vr);  
  fmiStatus setReal(ModelInstance* comp, const fmiValueReference vr, const fmiReal value);  
  fmiInteger getInteger(ModelInstance* comp, const fmiValueReference vr);  
  fmiStatus setInteger(ModelInstance* comp, const fmiValueReference vr, const fmiInteger value);  
  fmiBoolean getBoolean(ModelInstance* comp, const fmiValueReference vr);  
  fmiStatus setBoolean(ModelInstance* comp, const fmiValueReference vr, const fmiBoolean value);  
  fmiString getString(ModelInstance* comp, const fmiValueReference vr);    
  fmiStatus setExternalFunction(ModelInstance* c, const fmiValueReference vr, const void* value);
  
  <%ModelDefineData(modelInfo)%>
  
  // implementation of the Model Exchange functions
  #include "fmu_model_interface.c"
 
  <%setDefaultStartValues(modelInfo)%>
  <%setStartValues(modelInfo)%>
  <%eventUpdateFunction(simCode)%>
  <%getRealFunction(modelInfo)%>
  <%setRealFunction(modelInfo)%>
  <%getIntegerFunction(modelInfo)%>
  <%setIntegerFunction(modelInfo)%>
  <%getBooleanFunction(modelInfo)%>
  <%setBooleanFunction(modelInfo)%>
  <%getStringFunction(modelInfo)%>
  <%setExternalFunction(modelInfo)%>  
  
  #ifdef __cplusplus
  }
  #endif  
  
  >>
end fmumodel_identifierFile;

template ModelDefineData(ModelInfo modelInfo)
 "Generates global data in simulation file."
::=
match modelInfo
case MODELINFO(varInfo=VARINFO(__), vars=SIMVARS(stateVars = listStates)) then
let numberOfReals = intAdd(intMul(varInfo.numStateVars,2),intAdd(varInfo.numAlgVars,intAdd(varInfo.numParams,varInfo.numAlgAliasVars)))
let numberOfIntegers = intAdd(varInfo.numIntAlgVars,intAdd(varInfo.numIntParams,varInfo.numIntAliasVars))
let numberOfStrings = intAdd(varInfo.numStringAlgVars,intAdd(varInfo.numStringParamVars,varInfo.numStringAliasVars))
let numberOfBooleans = intAdd(varInfo.numBoolAlgVars,intAdd(varInfo.numBoolParams,varInfo.numBoolAliasVars))
  <<
  // define model size
  #define NUMBER_OF_STATES <%if intEq(varInfo.numStateVars,1) then statesnumwithDummy(listStates) else  varInfo.numStateVars%>
  #define NUMBER_OF_EVENT_INDICATORS <%varInfo.numZeroCrossings%>
  #define NUMBER_OF_REALS <%numberOfReals%>
  #define NUMBER_OF_INTEGERS <%numberOfIntegers%>
  #define NUMBER_OF_STRINGS <%numberOfStrings%>
  #define NUMBER_OF_BOOLEANS <%numberOfBooleans%>
  #define NUMBER_OF_EXTERNALFUNCTIONS <%countDynamicExternalFunctions(functions)%>
  
  // define variable data for model
  <%System.tmpTickReset(0)%>
  <%vars.stateVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.derivativeVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.algVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.paramVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.aliasVars |> var => DefineVariables(var) ;separator="\n"%>
  <%System.tmpTickReset(0)%>
  <%vars.intAlgVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.intParamVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.intAliasVars |> var => DefineVariables(var) ;separator="\n"%>
  <%System.tmpTickReset(0)%>
  <%vars.boolAlgVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.boolParamVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.boolAliasVars |> var => DefineVariables(var) ;separator="\n"%>
  <%System.tmpTickReset(0)%>
  <%vars.stringAlgVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.stringParamVars |> var => DefineVariables(var) ;separator="\n"%>
  <%vars.stringAliasVars |> var => DefineVariables(var) ;separator="\n"%>
  
  
  // define initial state vector as vector of value references
  #define STATES { <%vars.stateVars |> SIMVAR(__) => if stringEq(crefStr(name),"$dummy") then '' else '<%cref(name)%>_'  ;separator=", "%> }
  #define STATESDERIVATIVES { <%vars.derivativeVars |> SIMVAR(__) => if stringEq(crefStr(name),"der($dummy)") then '' else '<%cref(name)%>_'  ;separator=", "%> }  
  
  <%System.tmpTickReset(0)%>
  <%(functions |> fn => defineExternalFunction(fn) ; separator="\n")%>
  >>
end ModelDefineData;

template dervativeNameCStyle(ComponentRef cr)
 "Generates the name of a derivative in c style, replaces ( with _"
::=
  match cr
  case CREF_QUAL(ident = "$DER") then 'der_<%crefStr(componentRef)%>_'
end dervativeNameCStyle;

template DefineVariables(SimVar simVar)
 "Generates code for defining variables in c file for FMU target. "
::=
match simVar
  case SIMVAR(__) then
  let description = if comment then '// "<%comment%>"'
  if stringEq(crefStr(name),"$dummy") then 
  <<>>
  else if stringEq(crefStr(name),"der($dummy)") then
  <<>>
  else
  <<
  #define <%cref(name)%>_ <%System.tmpTick()%> <%description%>
  >>
end DefineVariables;

template defineExternalFunction(Function fn)
 "Generates external function definitions."
::=
  match fn
    case EXTERNAL_FUNCTION(dynamicLoad=true) then
      let fname = extFunctionName(extName, language)
      <<
      #define $P<%fname%> <%System.tmpTick()%>
      >> 
end defineExternalFunction;


template setDefaultStartValues(ModelInfo modelInfo)
 "Generates code in c file for function setStartValues() which will set start values for all variables." 
::=
match modelInfo
case MODELINFO(varInfo=VARINFO(numStateVars=numStateVars),vars=SIMVARS(__)) then
  <<
  // Set values for all variables that define a start value
  void setDefaultStartValues(ModelInstance *comp) {
  
  <%vars.stateVars |> var => initValsDefault(var,"realVars",0) ;separator="\n"%>
  <%vars.derivativeVars |> var => initValsDefault(var,"realVars",numStateVars) ;separator="\n"%>
  <%vars.algVars |> var => initValsDefault(var,"realVars",intMul(2,numStateVars)) ;separator="\n"%>
  <%vars.intAlgVars |> var => initValsDefault(var,"integerVars",0) ;separator="\n"%>
  <%vars.boolAlgVars |> var => initValsDefault(var,"booleanVars",0) ;separator="\n"%>
  <%vars.stringAlgVars |> var => initValsDefault(var,"stringVars",0) ;separator="\n"%>  
  <%vars.paramVars |> var => initParamsDefault(var,"realParameter") ;separator="\n"%>
  <%vars.intParamVars |> var => initParamsDefault(var,"integerParameter") ;separator="\n"%>
  <%vars.boolParamVars |> var => initParamsDefault(var,"booleanParameter") ;separator="\n"%>
  <%vars.stringParamVars |> var => initParamsDefault(var,"stringParameter") ;separator="\n"%>
  }
  >>
end setDefaultStartValues;

template setStartValues(ModelInfo modelInfo)
 "Generates code in c file for function setStartValues() which will set start values for all variables." 
::=
match modelInfo
case MODELINFO(varInfo=VARINFO(numStateVars=numStateVars),vars=SIMVARS(__)) then
  <<
  // Set values for all variables that define a start value
  void setStartValues(ModelInstance *comp) {
  
  <%vars.stateVars |> var => initVals(var,"realVars",0) ;separator="\n"%>
  <%vars.derivativeVars |> var => initVals(var,"realVars",numStateVars) ;separator="\n"%>
  <%vars.algVars |> var => initVals(var,"realVars",intMul(2,numStateVars)) ;separator="\n"%>
  <%vars.intAlgVars |> var => initVals(var,"integerVars",0) ;separator="\n"%>
  <%vars.boolAlgVars |> var => initVals(var,"booleanVars",0) ;separator="\n"%>
  <%vars.stringAlgVars |> var => initVals(var,"stringVars",0) ;separator="\n"%>  
  <%vars.paramVars |> var => initParams(var,"realParameter") ;separator="\n"%>
  <%vars.intParamVars |> var => initParams(var,"integerParameter") ;separator="\n"%>
  <%vars.boolParamVars |> var => initParams(var,"booleanParameter") ;separator="\n"%>
  <%vars.stringParamVars |> var => initParams(var,"stringParameter") ;separator="\n"%>
  }
  >>
end setStartValues;

template initializeFunction(list<SimEqSystem> allEquations)
  "Generates initialize function for c file."
::=
  let &varDecls = buffer "" /*BUFD*/
  let eqPart = ""/* (allEquations |> eq as SES_SIMPLE_ASSIGN(__) =>
      equation_(eq, contextOther, &varDecls)
    ;separator="\n") */
  <<
  // Used to set the first time event, if any.
  void initialize(ModelInstance* comp, fmiEventInfo* eventInfo) {

    <%varDecls%>
  
    <%eqPart%>
    <%allEquations |> SES_SIMPLE_ASSIGN(__) =>
      'if (sim_verbose) { printf("Setting variable start value: %s(start=%f)\n", "<%cref(cref)%>", <%cref(cref)%>); }'
    ;separator="\n"%>
  
  }
  >>
end initializeFunction;


template initVals(SimVar var, String arrayName, Integer offset) ::=
  match var
    case SIMVAR(__) then
    if stringEq(crefStr(name),"$dummy") then 
    <<>>
    else if stringEq(crefStr(name),"der($dummy)") then
    <<>>
    else
    let str = 'comp->fmuData->modelData.<%arrayName%>Data[<%intAdd(index,offset)%>].attribute.start'
    <<
      <%str%> =  comp->fmuData->localData[0]-><%arrayName%>[<%intAdd(index,offset)%>];
    >>
end initVals;

template initParams(SimVar var, String arrayName) ::=
  match var
    case SIMVAR(__) then
    let str = 'comp->fmuData->modelData.<%arrayName%>Data[<%index%>].attribute.start'
      '<%str%> = comp->fmuData->simulationInfo.<%arrayName%>[<%index%>];'
end initParams;


template initValsDefault(SimVar var, String arrayName, Integer offset) ::=
  match var
    case SIMVAR(index=index, type_=type_) then
    let str = 'comp->fmuData->modelData.<%arrayName%>Data[<%intAdd(index,offset)%>].attribute.start'
    match initialValue 
      case SOME(v) then 
      '<%str%> = <%initVal(v)%>;'
      case NONE() then
        match type_
          case T_INTEGER(__)
          case T_REAL(__)
          case T_ENUMERATION(__) 
          case T_BOOL(__) then '<%str%> = 0;'
          case T_STRING(__) then '<%str%> = "";'
          else 'UNKOWN_TYPE'
end initValsDefault;

template initParamsDefault(SimVar var, String arrayName) ::=
  match var
    case SIMVAR(__) then
    let str = 'comp->fmuData->modelData.<%arrayName%>Data[<%index%>].attribute.start'
    match initialValue 
      case SOME(v) then 
      '<%str%> = <%initVal(v)%>;'
end initParamsDefault;

template initVal(Exp initialValue) 
::=
  match initialValue 
  case ICONST(__) then integer
  case RCONST(__) then real
  case SCONST(__) then '"<%Util.escapeModelicaStringToXmlString(string)%>"'
  case BCONST(__) then if bool then "1" else "0"
  case ENUM_LITERAL(__) then '<%index%>/*ENUM:<%dotPath(name)%>*/'
  else "*ERROR* initial value of unknown type"
end initVal;

template eventUpdateFunction(SimCode simCode)
 "Generates event update function for c file."
::=
match simCode
case SIMCODE(__) then
  <<
  // Used to set the next time event, if any.
  void eventUpdate(ModelInstance* comp, fmiEventInfo* eventInfo) {
  }
  
  >>
end eventUpdateFunction;

template getRealFunction(ModelInfo modelInfo)
 "Generates getReal function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__),varInfo=VARINFO(numStateVars=numStateVars)) then
  <<
  fmiReal getReal(ModelInstance* comp, const fmiValueReference vr) {
    switch (vr) {
        <%vars.stateVars |> var => SwitchVars(var, "realVars", 0) ;separator="\n"%>
        <%vars.derivativeVars |> var => SwitchVars(var, "realVars", numStateVars) ;separator="\n"%>
        <%vars.algVars |> var => SwitchVars(var, "realVars", intMul(2,numStateVars)) ;separator="\n"%>
        <%vars.paramVars |> var => SwitchParameters(var, "realParameter") ;separator="\n"%>
        <%vars.aliasVars |> var => SwitchAliasVars(var, "Real","-") ;separator="\n"%>
        default: 
            return fmiError;
    }
  }
  
  >>        
end getRealFunction;

template setRealFunction(ModelInfo modelInfo)
 "Generates setReal function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__),varInfo=VARINFO(numStateVars=numStateVars)) then
  <<
  fmiStatus setReal(ModelInstance* comp, const fmiValueReference vr, const fmiReal value) {
    switch (vr) {
        <%vars.stateVars |> var => SwitchVarsSet(var, "realVars", 0) ;separator="\n"%>
        <%vars.derivativeVars |> var => SwitchVarsSet(var, "realVars", numStateVars) ;separator="\n"%>
        <%vars.algVars |> var => SwitchVarsSet(var, "realVars", intMul(2,numStateVars)) ;separator="\n"%>
        <%vars.paramVars |> var => SwitchParametersSet(var, "realParameter") ;separator="\n"%>
        <%vars.aliasVars |> var => SwitchAliasVarsSet(var, "Real", "-") ;separator="\n"%>
        default: 
            return fmiError;
    }
    return fmiOK;
  }
  
  >>
end setRealFunction;

template getIntegerFunction(ModelInfo modelInfo)
 "Generates setInteger function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  <<
  fmiInteger getInteger(ModelInstance* comp, const fmiValueReference vr) {
    switch (vr) {
        <%vars.intAlgVars |> var => SwitchVars(var, "integerVars", 0) ;separator="\n"%>
        <%vars.intParamVars |> var => SwitchParameters(var, "integerParameter") ;separator="\n"%>
        <%vars.intAliasVars |> var => SwitchAliasVars(var, "Integer", "-") ;separator="\n"%>
        default: 
            return 0;
    }
  }
  >>
end getIntegerFunction;

template setIntegerFunction(ModelInfo modelInfo)
 "Generates setInteger function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  <<
  fmiStatus setInteger(ModelInstance* comp, const fmiValueReference vr, const fmiInteger value) {
    switch (vr) {
        <%vars.intAlgVars |> var => SwitchVarsSet(var, "integerVars", 0) ;separator="\n"%>
        <%vars.intParamVars |> var => SwitchParametersSet(var, "integerParameter") ;separator="\n"%>
        <%vars.intAliasVars |> var => SwitchAliasVarsSet(var, "Integer", "-") ;separator="\n"%>        
        default: 
            return fmiError;
    }
    return fmiOK;
  }
  >>  
end setIntegerFunction;

template getBooleanFunction(ModelInfo modelInfo)
 "Generates setBoolean function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  <<
  fmiBoolean getBoolean(ModelInstance* comp, const fmiValueReference vr) {
    switch (vr) {
        <%vars.boolAlgVars |> var => SwitchVars(var, "booleanVars", 0) ;separator="\n"%>
        <%vars.boolParamVars |> var => SwitchParameters(var, "booleanParameter") ;separator="\n"%>
        <%vars.boolAliasVars |> var => SwitchAliasVars(var, "Boolean", "!") ;separator="\n"%>        
        default: 
            return 0;
    }
  }
  
  >>
end getBooleanFunction;

template setBooleanFunction(ModelInfo modelInfo)
 "Generates setBoolean function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  <<
  fmiStatus setBoolean(ModelInstance* comp, const fmiValueReference vr, const fmiBoolean value) {
    switch (vr) {
        <%vars.boolAlgVars |> var => SwitchVarsSet(var, "booleanVars", 0) ;separator="\n"%>
        <%vars.boolParamVars |> var => SwitchParametersSet(var, "booleanParameter") ;separator="\n"%>
        <%vars.boolAliasVars |> var => SwitchAliasVarsSet(var, "Boolean", "!") ;separator="\n"%> 
        default: 
            return fmiError;
    }
    return fmiOK;
  }
  
  >>       
end setBooleanFunction;

template getStringFunction(ModelInfo modelInfo)
 "Generates setString function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  <<
  fmiString getString(ModelInstance* comp, const fmiValueReference vr) {
    switch (vr) {
        <%vars.stringAlgVars |> var => SwitchVars(var, "stringVars", 0) ;separator="\n"%>
        <%vars.stringParamVars |> var => SwitchParameters(var, "stringParameter") ;separator="\n"%>
        <%vars.stringAliasVars |> var => SwitchAliasVars(var, "string", "") ;separator="\n"%>
        default: 
            return 0;
    }
  }
  
  >>
end getStringFunction;

template setStringFunction(ModelInfo modelInfo)
 "Generates setString function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  <<
  fmiString getString(ModelInstance* comp, const fmiValueReference vr) {
    switch (vr) {
        <%vars.stringAlgVars |> var => SwitchVarsSet(var, "stringVars", 0) ;separator="\n"%>
        <%vars.stringParamVars |> var => SwitchParametersSet(var, "stringParameter") ;separator="\n"%>
        <%vars.stringAliasVars |> var => SwitchAliasVarsSet(var, "String", "") ;separator="\n"%>    
        default: 
            return 0;
    }
  }
  
  >>
end setStringFunction;

template setExternalFunction(ModelInfo modelInfo)
 "Generates setString function for c file."
::=
match modelInfo
case MODELINFO(vars=SIMVARS(__)) then
  let externalFuncs = setExternalFunctionsSwitch(functions) 
  <<
  fmiStatus setExternalFunction(ModelInstance* c, const fmiValueReference vr, const void* value){
    switch (vr) {
        <%externalFuncs%>
        default: 
            return fmiError;
    }
    return fmiOK;
  }
  
  >>
end setExternalFunction;

template setExternalFunctionsSwitch(list<Function> functions)
 "Generates external function definitions."
::=  
  (functions |> fn => setExternalFunctionSwitch(fn) ; separator="\n")
end setExternalFunctionsSwitch;

template setExternalFunctionSwitch(Function fn)
 "Generates external function definitions."
::=
  match fn
    case EXTERNAL_FUNCTION(dynamicLoad=true) then
      let fname = extFunctionName(extName, language)
      <<
      case $P<%fname%> : ptr_<%fname%>=(ptrT_<%fname%>)value; break;
      >> 
end setExternalFunctionSwitch;

template SwitchVars(SimVar simVar, String arrayName, Integer offset)
 "Generates code for defining variables in c file for FMU target. "
::=
match simVar
  case SIMVAR(__) then
  let description = if comment then '// "<%comment%>"'
  if stringEq(crefStr(name),"$dummy") then 
  <<>>
  else if stringEq(crefStr(name),"der($dummy)") then
  <<>>
  else
  <<
  case <%cref(name)%>_ : return comp->fmuData->localData[0]-><%arrayName%>[<%intAdd(index,offset)%>]; break;
  >>
end SwitchVars;

template SwitchParameters(SimVar simVar, String arrayName)
 "Generates code for defining variables in c file for FMU target. "
::=
match simVar
  case SIMVAR(__) then
  let description = if comment then '// "<%comment%>"'
  <<
  case <%cref(name)%>_ : return comp->fmuData->simulationInfo.<%arrayName%>[<%index%>]; break;
  >>
end SwitchParameters;


template SwitchAliasVars(SimVar simVar, String arrayName, String negate)
 "Generates code for defining variables in c file for FMU target. "
::=
match simVar
  case SIMVAR(__) then
    let description = if comment then '// "<%comment%>"'
    let crefName = '<%cref(name)%>_'   
      match aliasvar
        case ALIAS(__) then 
        <<
        case <%crefName%> : return get<%arrayName%>(comp, <%cref(varName)%>_); break;
        >>
        case NEGATEDALIAS(__) then
        <<
        case <%crefName%> : return (<%negate%> get<%arrayName%>(comp, <%cref(varName)%>_)); break;
        >>
     end match 
end SwitchAliasVars;


template SwitchVarsSet(SimVar simVar, String arrayName, Integer offset)
 "Generates code for defining variables in c file for FMU target. "
::=
match simVar
  case SIMVAR(__) then
  let description = if comment then '// "<%comment%>"'
  if stringEq(crefStr(name),"$dummy") then 
  <<>>
  else if stringEq(crefStr(name),"der($dummy)") then
  <<>>
  else 
  <<
  case <%cref(name)%>_ : comp->fmuData->localData[0]-><%arrayName%>[<%intAdd(index,offset)%>]=value; break;
  >>
end SwitchVarsSet;

template SwitchParametersSet(SimVar simVar, String arrayName)
 "Generates code for defining variables in c file for FMU target. "
::=
match simVar
  case SIMVAR(__) then
  let description = if comment then '// "<%comment%>"'
  <<
  case <%cref(name)%>_ : comp->fmuData->simulationInfo.<%arrayName%>[<%index%>]=value; break;
  >>
end SwitchParametersSet;


template SwitchAliasVarsSet(SimVar simVar, String arrayName, String negate)
 "Generates code for defining variables in c file for FMU target. "
::=
match simVar
  case SIMVAR(__) then
    let description = if comment then '// "<%comment%>"'
    let crefName = '<%cref(name)%>_'
      match aliasvar
        case ALIAS(__) then 
        <<
        case <%crefName%> : return set<%arrayName%>(comp, <%cref(varName)%>_, value); break;
        >>
        case NEGATEDALIAS(__) then
        <<
        case <%crefName%> : return set<%arrayName%>(comp, <%cref(varName)%>_, (<%negate%> value)); break;
        >>
     end match 
end SwitchAliasVarsSet;


template getPlatformString2(String platform, String fileNamePrefix, String dirExtra, String libsPos1, String libsPos2, String omhome)
 "returns compilation commands for the platform. "
::=
match platform
  case "win32" then
  << 
  <%fileNamePrefix%>_FMU: <%fileNamePrefix%>.def <%fileNamePrefix%>.dll
  <%\t%> dlltool -d <%fileNamePrefix%>.def --dllname <%fileNamePrefix%>.dll --output-lib <%fileNamePrefix%>.lib --kill-at
        
  <%\t%> cp <%fileNamePrefix%>.dll <%fileNamePrefix%>/binaries/<%platform%>/
  <%\t%> cp <%fileNamePrefix%>.lib <%fileNamePrefix%>/binaries/<%platform%>/
  <%\t%> cp <%fileNamePrefix%>.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>.c
  <%\t%> cp _<%fileNamePrefix%>.h <%fileNamePrefix%>/sources/_<%fileNamePrefix%>.h
  <%\t%> cp <%fileNamePrefix%>_FMU.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>_FMU.c
  <%\t%> cp <%fileNamePrefix%>_functions.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>_functions.c
  <%\t%> cp <%fileNamePrefix%>_functions.h <%fileNamePrefix%>/sources/<%fileNamePrefix%>_functions.h
  <%\t%> cp <%fileNamePrefix%>_records.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>_records.c
  <%\t%> cp modelDescription.xml <%fileNamePrefix%>/modelDescription.xml
  <%\t%> cp <%omhome%>/lib/omc/libexec/gnuplot/binary/libexpat-1.dll <%fileNamePrefix%>/binaries/<%platform%>/
  <%\t%> cd <%fileNamePrefix%>&& rm -f ../<%fileNamePrefix%>.fmu&& zip -r ../<%fileNamePrefix%>.fmu *
  <%\t%> rm -rf <%fileNamePrefix%>
  <%\t%> rm -f <%fileNamePrefix%>.def <%fileNamePrefix%>.o <%fileNamePrefix%>_FMU.libs <%fileNamePrefix%>_FMU.makefile <%fileNamePrefix%>_FMU.o <%fileNamePrefix%>_records.o
  
  <%fileNamePrefix%>.dll: clean <%fileNamePrefix%>_FMU.o <%fileNamePrefix%>.o <%fileNamePrefix%>_records.o
  <%\t%> $(CXX) -shared -I. -o <%fileNamePrefix%>.dll <%fileNamePrefix%>_FMU.o <%fileNamePrefix%>.o <%fileNamePrefix%>_records.o  $(CPPFLAGS) <%dirExtra%> <%libsPos1%> <%libsPos2%> $(CFLAGS) $(LDFLAGS) <%match System.os() case "OSX" then "-lf2c" else "-Wl,-Bstatic -lf2c -Wl,-Bdynamic"%> -Wl,--kill-at
  
  <%\t%> "mkdir.exe" -p <%fileNamePrefix%>
  <%\t%> "mkdir.exe" -p <%fileNamePrefix%>/binaries
  <%\t%> "mkdir.exe" -p <%fileNamePrefix%>/binaries/<%platform%>
  <%\t%> "mkdir.exe" -p <%fileNamePrefix%>/sources
  >>    
  else
  << 
  <%fileNamePrefix%>_FMU: <%fileNamePrefix%>_FMU.o <%fileNamePrefix%>.o <%fileNamePrefix%>_records.o
  <%\t%> $(CXX) -shared -I. -o <%fileNamePrefix%>$(DLLEXT) <%fileNamePrefix%>_FMU.o <%fileNamePrefix%>.o <%fileNamePrefix%>_records.o $(CPPFLAGS) <%dirExtra%> <%libsPos1%> <%libsPos2%> $(CFLAGS) $(LDFLAGS) <%match System.os() case "OSX" then "-lf2c" else "-Wl,-Bstatic -lf2c -Wl,-Bdynamic"%>

  <%\t%> mkdir -p <%fileNamePrefix%>
  <%\t%> mkdir -p <%fileNamePrefix%>/binaries

  <%\t%> mkdir -p <%fileNamePrefix%>/binaries/<%platform%>
  <%\t%> mkdir -p <%fileNamePrefix%>/sources

  <%\t%> cp <%fileNamePrefix%>$(DLLEXT) <%fileNamePrefix%>/binaries/<%platform%>/
  <%\t%> cp <%fileNamePrefix%>_FMU.libs <%fileNamePrefix%>/binaries/<%platform%>/
  <%\t%> cp <%fileNamePrefix%>.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>.c
  <%\t%> cp _<%fileNamePrefix%>.h <%fileNamePrefix%>/sources/_<%fileNamePrefix%>.h
  <%\t%> cp <%fileNamePrefix%>_FMU.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>_FMU.c
  <%\t%> cp <%fileNamePrefix%>_functions.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>_functions.c
  <%\t%> cp <%fileNamePrefix%>_functions.h <%fileNamePrefix%>/sources/<%fileNamePrefix%>_functions.h
  <%\t%> cp <%fileNamePrefix%>_records.c <%fileNamePrefix%>/sources/<%fileNamePrefix%>_records.c 
  <%\t%> cp modelDescription.xml <%fileNamePrefix%>/modelDescription.xml
  <%\t%> cd <%fileNamePrefix%>; rm -f ../<%fileNamePrefix%>.fmu && zip -r ../<%fileNamePrefix%>.fmu *
  <%\t%> rm -rf <%fileNamePrefix%>
  <%\t%> rm -f <%fileNamePrefix%>.def <%fileNamePrefix%>.o <%fileNamePrefix%>_FMU.libs <%fileNamePrefix%>_FMU.makefile <%fileNamePrefix%>_FMU.o <%fileNamePrefix%>_records.o
  
  >>
end getPlatformString2; 

template fmuMakefile(SimCode simCode)
 "Generates the contents of the makefile for the simulation case. Copy libexpat & correct linux fmu"
::=
match simCode
case SIMCODE(modelInfo=MODELINFO(__), makefileParams=MAKEFILE_PARAMS(__), simulationSettingsOpt = sopt) then
  let dirExtra = if modelInfo.directory then '-L"<%modelInfo.directory%>"' //else ""
  let libsStr = (makefileParams.libs |> lib => lib ;separator=" ")
  let libsPos1 = if not dirExtra then libsStr //else ""
  let libsPos2 = if dirExtra then libsStr // else ""
  let extraCflags = match sopt case SOME(s as SIMULATION_SETTINGS(__)) then
    '<%if s.measureTime then "-D_OMC_MEASURE_TIME "%> <%match s.method
       case "inline-euler" then "-D_OMC_INLINE_EULER"
       case "inline-rungekutta" then "-D_OMC_INLINE_RK"%>'
  let compilecmds = getPlatformString2(makefileParams.platform, fileNamePrefix, dirExtra, libsPos1, libsPos2, makefileParams.omhome)
  <<
  # Makefile generated by OpenModelica
 
  # Simulation of the fmu with dymola does not work 
  # with inline-small-functions
  SIM_OR_DYNLOAD_OPT_LEVEL=-O #-O2  -fno-inline-small-functions
  CC=<%makefileParams.ccompiler%>
  CXX=<%makefileParams.cxxcompiler%>
  LINK=<%makefileParams.linker%>
  EXEEXT=<%makefileParams.exeext%>
  DLLEXT=<%makefileParams.dllext%>
  CFLAGS_BASED_ON_INIT_FILE=<%extraCflags%>
  PLATLINUX = <%makefileParams.platform%>
  PLAT34 = <%makefileParams.platform%>
  CFLAGS=$(CFLAGS_BASED_ON_INIT_FILE) -I"<%makefileParams.omhome%>/include/omc" <%makefileParams.cflags%> <%match sopt case SOME(s as SIMULATION_SETTINGS(__)) then s.cflags /* From the simulate() command */%>
  CPPFLAGS=-I"<%makefileParams.omhome%>/include/omc" -I. <%dirExtra%> <%makefileParams.includes ; separator=" "%>
  LDFLAGS=-L"<%makefileParams.omhome%>/lib/omc" -lSimulationRuntimeC -linteractive <%makefileParams.ldflags%> <%makefileParams.runtimelibs%>
  PERL=perl
  MAINFILE=<%fileNamePrefix%>_FMU<% if acceptMetaModelicaGrammar() then ".conv"%>.c
  MAINOBJ=<%fileNamePrefix%>_FMU<% if acceptMetaModelicaGrammar() then ".conv"%>.o  
  
  PHONY: <%fileNamePrefix%>_FMU
  <%compilecmds%>
  
  <%fileNamePrefix%>.conv.c: <%fileNamePrefix%>.c
  <%\t%> $(PERL) <%makefileParams.omhome%>/share/omc/scripts/convert_lines.pl $< $@.tmp
  <%\t%> @mv $@.tmp $@
  $(MAINOBJ): $(MAINFILE) <%fileNamePrefix%>.c <%fileNamePrefix%>_functions.c <%fileNamePrefix%>_functions.h
  clean:
  <%\t%> @rm -f <%fileNamePrefix%>_records.o $(MAINOBJ) <%fileNamePrefix%>_FMU.o <%fileNamePrefix%>.o 
  >>
end fmuMakefile;

template fmudeffile(SimCode simCode)
 "Generates the def file of the fmu."
::=
match simCode
case SIMCODE(modelInfo=MODELINFO(__), makefileParams=MAKEFILE_PARAMS(__), simulationSettingsOpt = sopt) then
  <<
  EXPORTS
    <%fileNamePrefix%>_fmiCompletedIntegratorStep @1
    <%fileNamePrefix%>_fmiEventUpdate @2
    <%fileNamePrefix%>_fmiFreeModelInstance @3
    <%fileNamePrefix%>_fmiGetBoolean @4
    <%fileNamePrefix%>_fmiGetContinuousStates @5
    <%fileNamePrefix%>_fmiGetDerivatives @6
    <%fileNamePrefix%>_fmiGetEventIndicators @7
    <%fileNamePrefix%>_fmiGetInteger @8
    <%fileNamePrefix%>_fmiGetModelTypesPlatform @9
    <%fileNamePrefix%>_fmiGetNominalContinuousStates @10
    <%fileNamePrefix%>_fmiGetReal @11
    <%fileNamePrefix%>_fmiGetStateValueReferences @12
    <%fileNamePrefix%>_fmiGetString @13
    <%fileNamePrefix%>_fmiGetVersion @14
    <%fileNamePrefix%>_fmiInitialize @15
    <%fileNamePrefix%>_fmiInstantiateModel @16
    <%fileNamePrefix%>_fmiSetBoolean @17
    <%fileNamePrefix%>_fmiSetContinuousStates @18
    <%fileNamePrefix%>_fmiSetDebugLogging @19
    <%fileNamePrefix%>_fmiSetExternalFunction @20
    <%fileNamePrefix%>_fmiSetInteger @21
    <%fileNamePrefix%>_fmiSetReal @22
    <%fileNamePrefix%>_fmiSetString @23
    <%fileNamePrefix%>_fmiSetTime @24
    <%fileNamePrefix%>_fmiTerminate @25
  >>
end fmudeffile;

template importFMUModelica(FmiImport fmi)
 "Generates the Modelica code from the FMU's modelDescription file."
::=
match fmi
case FMIIMPORT(fmiInfo=INFO(__),fmiExperimentAnnotation=EXPERIMENTANNOTATION(__)) then
  match fmiInfo.fmiType
    case 0 then
      importFMUModelExchange(fmi)
    case 1 then
      importFMUCoSimulationStandAlone(fmi)
end importFMUModelica;

template importFMUModelExchange(FmiImport fmi)
 "Generates Modelica code for FMI Model Exchange."
::=
match fmi
case FMIIMPORT(fmiInfo=INFO(__),fmiExperimentAnnotation=EXPERIMENTANNOTATION(__)) then
  let realVariables = countRealVariables(fmiModelVariablesList)
  let realStartVariablesValueReferences = dumpStartRealVariablesValueReference(fmiModelVariablesList)
  let realStartVariablesNames = dumpStartRealVariablesName(fmiModelVariablesList)
  let integerVariables = countIntegerVariables(fmiModelVariablesList)
  let integerStartVariablesValueReferences = dumpStartIntegerVariablesValueReference(fmiModelVariablesList)
  let integerStartVariablesNames = dumpStartIntegerVariablesName(fmiModelVariablesList)
  let booleanVariables = countBooleanVariables(fmiModelVariablesList)
  let booleanStartVariablesValueReferences = dumpStartBooleanVariablesValueReference(fmiModelVariablesList)
  let booleanStartVariablesNames = dumpStartBooleanVariablesName(fmiModelVariablesList)
  let stringVariables = countStringVariables(fmiModelVariablesList)
  let stringStartVariablesValueReferences = dumpStartStringVariablesValueReference(fmiModelVariablesList)
  let stringStartVariablesNames = dumpStartStringVariablesName(fmiModelVariablesList)
  <<
  model <%fmiInfo.fmiModelIdentifier%>_<%getFMIType(fmiInfo)%>_FMU<%if stringEq(fmiInfo.fmiDescription, "") then "" else " \""+fmiInfo.fmiDescription+"\""%>
  public
    constant String fmuFile = "<%fmuFileName%>";
    constant String fmuWorkingDir = "<%fmuWorkingDirectory%>";
    constant Integer fmiLogLevel = <%fmiLogLevel%>;
    constant Boolean debugLogging = false;
    fmiImportInstance fmi = fmiImportInstance(context, fmuWorkingDir);
    fmiImportContext context = fmiImportContext(fmiLogLevel);
    fmiEventInfo eventInfo;
    <%dumpFMIModelVariablesList(fmiModelVariablesList)%>
    constant Integer numberOfContinuousStates = <%listLength(fmiInfo.fmiNumberOfContinuousStates)%>;
    Real fmi_x[numberOfContinuousStates] "States";
    Real fmi_x_new[numberOfContinuousStates] "New States";
    constant Integer numberOfEventIndicators = <%listLength(fmiInfo.fmiNumberOfEventIndicators)%>;
    Real fmi_z[numberOfEventIndicators] "Events Indicators";
    Boolean fmi_z_positive[numberOfEventIndicators];
    Real flowTimeNext;
    parameter Real flowInit(fixed=false);
    parameter Real flowInitInputs(fixed=false);
    parameter Real flowParamsStart(fixed=false);
    Real flowTime;
    Real flowStatesInputs = flowStates;
    Real flowStates;
    Boolean callEventUpdate;
    Boolean newStatesAvailable;
    Integer fmi_status;
  initial algorithm
    <%if not boolAnd(stringEq(realStartVariablesValueReferences, ""), stringEq(realStartVariablesNames, "")) then "flowParamsStart := fmiFunctions.fmiSetReal(fmi, {"+realStartVariablesValueReferences+"}, {"+realStartVariablesNames+"});"%>
    <%if not boolAnd(stringEq(integerStartVariablesValueReferences, ""), stringEq(integerStartVariablesNames, "")) then "flowParamsStart := fmiFunctions.fmiSetInteger(fmi, {"+integerStartVariablesValueReferences+"}, {"+integerStartVariablesNames+"});"%>
    <%if not boolAnd(stringEq(booleanStartVariablesValueReferences, ""), stringEq(booleanStartVariablesNames, "")) then "flowParamsStart := fmiFunctions.fmiSetBoolean(fmi, {"+booleanStartVariablesValueReferences+"}, {"+booleanStartVariablesNames+"});"%>
    <%if not boolAnd(stringEq(stringStartVariablesValueReferences, ""), stringEq(stringStartVariablesNames, "")) then "flowParamsStart := fmiFunctions.fmiSetString(fmi, {"+stringStartVariablesValueReferences+"}, {"+stringStartVariablesNames+"});"%>
  initial equation
    (flowTimeNext,flowInit,eventInfo) = fmiFunctions.fmiInitialize(fmi, "BouncingBall", debugLogging, time, eventInfo, flowParamsStart+flowInitInputs);
  <%if intGt(listLength(fmiInfo.fmiNumberOfContinuousStates), 0) then
  <<
    fmi_x = fmiFunctions.fmiGetContinuousStates(fmi, numberOfContinuousStates, flowParamsStart+flowInit);
  >>
  %>
  equation
    flowTime = fmiFunctions.fmiSetTime(fmi, time, 1);
    flowStates = fmiFunctions.fmiSetContinuousStates(fmi, fmi_x, flowParamsStart + flowTime);
    der(fmi_x) = fmiFunctions.fmiGetDerivatives(fmi, numberOfContinuousStates, flowStatesInputs);
    fmi_z  = fmiFunctions.fmiGetEventIndicators(fmi, numberOfEventIndicators, flowStatesInputs);
    for i in 1:size(fmi_z,1) loop
      fmi_z_positive[i] = if not terminal() then fmi_z[i] > 0 else pre(fmi_z_positive[i]);
    end for;
    callEventUpdate = fmiFunctions.fmiCompletedIntegratorStep(fmi, flowStatesInputs);
    <%if not stringEq(realVariables, "0") then "{"+dumpRealVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetReal(fmi, {"+dumpRealVariablesVR(fmiModelVariablesList)+"}, flowStatesInputs);"%>
    <%if not stringEq(integerVariables, "0") then "{"+dumpIntegerVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetInteger(fmi, {"+dumpIntegerVariablesVR(fmiModelVariablesList)+"}, flowStatesInputs);"%>
    <%if not stringEq(booleanVariables, "0") then "{"+dumpBooleanVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetBoolean(fmi, {"+dumpBooleanVariablesVR(fmiModelVariablesList)+"}, flowStatesInputs);"%>
    <%if not stringEq(stringVariables, "0") then "{"+dumpStringVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetString(fmi, {"+dumpStringVariablesVR(fmiModelVariablesList)+"}, flowStatesInputs);"%>
  algorithm
  <%if intGt(listLength(fmiInfo.fmiNumberOfEventIndicators), 0) then
  <<
    when (<%fmiInfo.fmiNumberOfEventIndicators |> eventIndicator =>  "change(fmi_z_positive["+eventIndicator+"])" ;separator=" or "%>) and not initial() then
  >>
  else
  <<
    when not initial() then
  >>
  %>
      (flowTimeNext, newStatesAvailable) := fmiFunctions.fmiEventUpdate(fmi, false, eventInfo, flowStatesInputs);
  <%if intGt(listLength(fmiInfo.fmiNumberOfContinuousStates), 0) then
  <<
      if newStatesAvailable then
        fmi_x_new := fmiFunctions.fmiGetContinuousStates(fmi, numberOfContinuousStates, flowStatesInputs);
        <%fmiInfo.fmiNumberOfContinuousStates |> continuousStates =>  "reinit(fmi_x["+continuousStates+"], fmi_x_new["+continuousStates+"]);" ;separator="\n"%>
      end if;
  >>
  %>
    end when;
    when terminal() then
      fmi_status := fmiFunctions.fmiTerminate(fmi);
    end when;
    annotation(experiment(StartTime=<%fmiExperimentAnnotation.fmiExperimentStartTime%>, StopTime=<%fmiExperimentAnnotation.fmiExperimentStopTime%>, Tolerance=<%fmiExperimentAnnotation.fmiExperimentTolerance%>));
  protected
    <%dumpFMICommonObjects(platform)%>
    
    class fmiEventInfo
      extends ExternalObject;
        function constructor
        end constructor;
        
        function destructor
          input fmiEventInfo eventInfo;
          external "C" fmiFreeEventInfo_OMC(eventInfo) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
        end destructor;
    end fmiEventInfo;
    
    package fmiFunctions
      function fmiInitialize
        input fmiImportInstance fmi;
        input String instanceName;
        input Boolean debugLogging;
        input Real in_Time;
        input fmiEventInfo in_EventInfo;
        input Real in_Flow_Init_Inputs;
        output Real out_Flow_Time;
        output Real out_Flow_Init;
        output fmiEventInfo out_eventInfo;
        external "C" out_eventInfo = fmiInitialize_OMC(fmi, instanceName, debugLogging, in_Time, in_EventInfo, in_Flow_Init_Inputs, out_Flow_Time, out_Flow_Init) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiInitialize;
      
      function fmiSetTime
        input fmiImportInstance fmi;
        input Real in_Time;
        input Real in_Flow;
        output Real status;
        external "C" status = fmiSetTime_OMC(fmi, in_Time, in_Flow) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiSetTime;
      
      function fmiGetContinuousStates
        input fmiImportInstance fmi;
        input Integer numberOfContinuousStates;
        input Real in_Flow_Init;
        output Real fmi_x[numberOfContinuousStates];
        external "C" fmiGetContinuousStates_OMC(fmi, numberOfContinuousStates, in_Flow_Init, fmi_x) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiGetContinuousStates;
      
      function fmiSetContinuousStates
        input fmiImportInstance fmi;
        input Real fmi_x[:];
        input Real in_Flow_Time;
        output Real out_Flow_States;
        external "C" out_Flow_States = fmiSetContinuousStates_OMC(fmi, size(fmi_x, 1), fmi_x, in_Flow_Time) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiSetContinuousStates;
      
      function fmiGetEventIndicators
        input fmiImportInstance fmi;
        input Integer numberOfEventIndicators;
        input Real in_Flow_Event;
        output Real fmi_z[numberOfEventIndicators];
        external "C" fmiGetEventIndicators_OMC(fmi, numberOfEventIndicators, in_Flow_Event, fmi_z) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiGetEventIndicators;
      
      function fmiGetDerivatives
        input fmiImportInstance fmi;
        input Integer numberOfContinuousStates;
        input Real in_Flow_States_Input;
        output Real fmi_x[numberOfContinuousStates];
        external "C" fmiGetDerivatives_OMC(fmi, numberOfContinuousStates, in_Flow_States_Input, fmi_x) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiGetDerivatives;
      
      <%dumpFMICommonFunctions(platform)%>
      
      function fmiEventUpdate
        input fmiImportInstance fmi;
        input Boolean intermediateResults;
        input fmiEventInfo in_eventInfo;
        input Real in_Flow_States;
        output Real out_Flow_Time;
        output Boolean out_NewStates;
        external "C" out_NewStates = fmiEventUpdate_OMC(fmi, intermediateResults, in_eventInfo, in_Flow_States, out_Flow_Time) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiEventUpdate;
      
      function fmiCompletedIntegratorStep
        input fmiImportInstance fmi;
        input Real in_Flow_States;
        output Boolean out_callEventUpdate;
        external "C" out_callEventUpdate = fmiCompletedIntegratorStep_OMC(fmi, in_Flow_States) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiCompletedIntegratorStep;
      
      function fmiTerminate
        input fmiImportInstance fmi;
        output Integer status;
        external "C" status = fmiTerminate_OMC(fmi) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiTerminate;
    end fmiFunctions;
    
    package fmiStatus
      constant Integer fmiOK=0;
      constant Integer fmiWarning=1;
      constant Integer fmiDiscard=2;
      constant Integer fmiError=3;
      constant Integer fmiFatal=4;
      constant Integer fmiPending=5;
    end fmiStatus;
  end <%fmiInfo.fmiModelIdentifier%>_<%getFMIType(fmiInfo)%>_FMU;
  >>
end importFMUModelExchange;

template importFMUCoSimulationStandAlone(FmiImport fmi)
 "Generates Modelica code for FMI Co-simulation stand alone."
::=
match fmi
case FMIIMPORT(fmiInfo=INFO(__),fmiExperimentAnnotation=EXPERIMENTANNOTATION(__)) then
  let realVariables = countRealVariables(fmiModelVariablesList)
  let realStartVariables = countRealStartVariables(fmiModelVariablesList)
  let integerVariables = countIntegerVariables(fmiModelVariablesList)
  let integerStartVariables = countIntegerStartVariables(fmiModelVariablesList)
  let booleanVariables = countBooleanVariables(fmiModelVariablesList)
  let booleanStartVariables = countBooleanStartVariables(fmiModelVariablesList)
  let stringVariables = countStringVariables(fmiModelVariablesList)
  let stringStartVariables = countStringStartVariables(fmiModelVariablesList)
  <<
  model <%fmiInfo.fmiModelIdentifier%>_<%getFMIType(fmiInfo)%>_FMU<%if stringEq(fmiInfo.fmiDescription, "") then "" else " \""+fmiInfo.fmiDescription+"\""%>
  public
    constant String fmuFile = "<%fmuFileName%>";
    constant String fmuWorkingDir = "<%fmuWorkingDirectory%>";
    constant Integer fmiLogLevel = <%fmiLogLevel%>;
    constant String mimeType = "";
    constant Real timeout = 0.0;
    constant Boolean visible = false;
    constant Boolean interactive = false;
    constant Real communicationStepSize = 0.005;
    <%dumpFMIModelVariablesList(fmiModelVariablesList)%>
    constant Boolean debugLogging = false;
    fmiImportInstance fmi = fmiImportInstance(context, fmuWorkingDir);
    fmiImportContext context = fmiImportContext(fmiLogLevel);
    Real flowControl;
    Boolean initializationDone(start=false);
  protected
    <%dumpFMICommonObjects(platform)%>
    
    package fmiFunctions
      function fmiInstantiateSlave
        input fmiImportInstance fmi;
        input String instanceName;
        input String fmuLocation;
        input String mimeType;
        input Real timeout;
        input Boolean visible;
        input Boolean interactive;
        external "C" fmiInstantiateSlave_OMC(fmi, instanceName, fmuLocation, mimeType, timeout, visible, interactive) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiInstantiateSlave;
      
      function fmiInitializeSlave
        input fmiImportInstance fmi;
        input Real tStart;
        input Boolean stopTimeDefined;
        input Real tStop;
        external "C" fmiInitializeSlave_OMC(fmi, tStart, stopTimeDefined, tStop) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiInitializeSlave;
      
      function fmiDoStep
        input fmiImportInstance fmi;
        input Real currentCommunicationPoint;
        input Real communicationStepSize;
        input Boolean newStep;
        output Real out_Flow;
        external "C" out_Flow = fmiDoStep_OMC(fmi, currentCommunicationPoint, communicationStepSize, newStep) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiDoStep;
      
      <%dumpFMICommonFunctions(platform)%>
      
      function fmiTerminateSlave
        input fmiImportInstance fmi;
        output Integer status;
        external "C" status = fmiTerminateSlave_OMC(fmi) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end fmiTerminateSlave;
    end fmiFunctions;
    
    package fmiStatus
      constant Integer fmiOK=0;
      constant Integer fmiWarning=1;
      constant Integer fmiDiscard=2;
      constant Integer fmiError=3;
      constant Integer fmiFatal=4;
      constant Integer fmiPending=5;
    end fmiStatus;
  initial algorithm
    if not initializationDone then
      fmiFunctions.fmiInstantiateSlave(fmi, "<%fmiInfo.fmiModelIdentifier%>", fmuFile, mimeType, timeout, visible, interactive);
      fmiFunctions.fmiSetDebugLogging(fmi, debugLogging);
      fmiFunctions.fmiInitializeSlave(fmi, <%fmiExperimentAnnotation.fmiExperimentStartTime%>, false, <%fmiExperimentAnnotation.fmiExperimentStopTime%>);
      initializationDone := true;
    end if;
  algorithm
    initializationDone := true;
  equation
    flowControl = fmiFunctions.fmiDoStep(fmi, time, communicationStepSize, true);
    <%if not stringEq(realVariables, "0") then "{"+dumpRealVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetReal(fmi, {"+dumpRealVariablesVR(fmiModelVariablesList)+"}, flowControl);"%>
    <%if not stringEq(integerVariables, "0") then "{"+dumpIntegerVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetInteger(fmi, {"+dumpIntegerVariablesVR(fmiModelVariablesList)+"}, flowControl);"%>
    <%if not stringEq(booleanVariables, "0") then "{"+dumpBooleanVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetBoolean(fmi, {"+dumpBooleanVariablesVR(fmiModelVariablesList)+"}, flowControl);"%>
    <%if not stringEq(stringVariables, "0") then "{"+dumpStringVariablesName(fmiModelVariablesList)+"} = fmiFunctions.fmiGetString(fmi, {"+dumpStringVariablesVR(fmiModelVariablesList)+"}, flowControl);"%>
  algorithm
    when terminal() then
      fmiFunctions.fmiTerminateSlave(fmi);
    end when;
    annotation(experiment(StartTime=<%fmiExperimentAnnotation.fmiExperimentStartTime%>, StopTime=<%fmiExperimentAnnotation.fmiExperimentStopTime%>, Tolerance=<%fmiExperimentAnnotation.fmiExperimentTolerance%>));
  end <%fmiInfo.fmiModelIdentifier%>_<%getFMIType(fmiInfo)%>_FMU;
  >>
end importFMUCoSimulationStandAlone;

template dumpFMICommonObjects(String platform)
  "Generates the common FMI external objects used by OMC to reference FMIL Objects."
::=
  <<
  class fmiImportContext
    extends ExternalObject;
      function constructor
        input Integer fmiLogLevel;
        output fmiImportContext context;
        external "C" context = fmiImportContext_OMC(fmiLogLevel) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end constructor;
      
      function destructor
        input fmiImportContext context;
        external "C" fmiImportFreeContext_OMC(context) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end destructor;
  end fmiImportContext;
  
  class fmiImportInstance
    extends ExternalObject;
      function constructor
        input fmiImportContext context;
        input String tempPath;
        output fmiImportInstance fmi;
        external "C" fmi = fmiImportInstance_OMC(context, tempPath) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end constructor;
      
      function destructor
        input fmiImportInstance fmi;
        external "C" fmiImportFreeInstance_OMC(fmi) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
      end destructor;
  end fmiImportInstance;
  >>
end dumpFMICommonObjects;

template dumpFMICommonFunctions(String platform)
 "Generates the common FMI functions wrapped by OMC."
::=
  <<
  function fmiSetDebugLogging
    input fmiImportInstance fmi;
    input Boolean debugLogging;
    output Integer status;
    external "C" status = fmiSetDebugLogging_OMC(fmi, debugLogging) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiSetDebugLogging;
      
  function fmiGetReal
    input fmiImportInstance fmi;
    input Real realValuesReferences[:];
    input Real in_Flow;
    output Real realValues[size(realValuesReferences, 1)];
    external "C" fmiGetReal_OMC(fmi, size(realValuesReferences, 1), realValuesReferences, realValues, in_Flow) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiGetReal;

  function fmiSetReal
    input fmiImportInstance fmi;
    input Real realValuesReferences[:];
    input Real realValues[size(realValuesReferences, 1)];
    output Real out_Flow_Params;
    external "C" out_Flow_Params = fmiSetReal_OMC(fmi, size(realValuesReferences, 1), realValuesReferences, realValues) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiSetReal;

  function fmiGetInteger
    input fmiImportInstance fmi;
    input Real integerValuesReferences[:];
    input Real in_Flow;
    output Integer integerValues[size(integerValuesReferences, 1)];
    external "C" fmiGetInteger_OMC(fmi, size(integerValuesReferences, 1), integerValuesReferences, integerValues, in_Flow) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiGetInteger;

  function fmiSetInteger
    input fmiImportInstance fmi;
    input Real integerValuesReferences[:];
    input Integer integerValues[size(integerValuesReferences, 1)];
    output Real out_Flow_Params;
    external "C" out_Flow_Params = fmiSetInteger_OMC(fmi, size(integerValuesReferences, 1), integerValuesReferences, integerValues) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiSetInteger;

  function fmiGetBoolean
    input fmiImportInstance fmi;
    input Real booleanValuesReferences[:];
    input Real in_Flow;
    output Boolean booleanValues[size(booleanValuesReferences, 1)];
    external "C" fmiGetBoolean_OMC(fmi, size(booleanValuesReferences, 1), booleanValuesReferences, booleanValues, in_Flow) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiGetBoolean;

  function fmiSetBoolean
    input fmiImportInstance fmi;
    input Real booleanValuesReferences[:];
    input Boolean booleanValues[size(booleanValuesReferences, 1)];
    output Real out_Flow_Params;
    external "C" out_Flow_Params = fmiSetBoolean_OMC(fmi, size(booleanValuesReferences, 1), booleanValuesReferences, booleanValues) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiSetBoolean;

  function fmiGetString
    input fmiImportInstance fmi;
    input Real stringValuesReferences[:];
    input Real in_Flow;
    output String stringValues[size(stringValuesReferences, 1)];
    external "C" fmiGetString_OMC(fmi, size(stringValuesReferences, 1), stringValuesReferences, stringValues, in_Flow) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiGetString;

  function fmiSetString
    input fmiImportInstance fmi;
    input Real stringValuesReferences[:];
    input String stringValues[size(stringValuesReferences, 1)];
    output Real out_Flow_Params;
    external "C" out_Flow_Params = fmiSetString_OMC(fmi, size(stringValuesReferences, 1), stringValuesReferences, stringValues) annotation(Library = {"omcruntime", "fmilib"<%if stringEq(platform, "win32") then ", \"shlwapi\""%>});
  end fmiSetString;
  >>
end dumpFMICommonFunctions;

template dumpFMIModelVariablesList(list<ModelVariables> fmiModelVariablesList)
 "Generates the Model Variables code."
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpFMIModelVariable(fmiModelVariable) ;separator="\n"%>
  >>
end dumpFMIModelVariablesList;

template dumpFMIModelVariable(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case REALVARIABLE(__) then
  <<
  <%dumpFMIModelVariableVariability(variability)%><%dumpFMIModelVariableCausality(causality)%><%baseType%> <%name%><%dumpFMIRealModelVariableStartValue(hasStartValue, startValue, isFixed)%><%dumpFMIModelVariableDescription(description)%>;
  >>
case INTEGERVARIABLE(__) then
  <<
  <%dumpFMIModelVariableVariability(variability)%><%dumpFMIModelVariableCausality(causality)%><%baseType%> <%name%><%dumpFMIIntegerModelVariableStartValue(hasStartValue, startValue, isFixed)%><%dumpFMIModelVariableDescription(description)%>;
  >>
case BOOLEANVARIABLE(__) then
  <<
  <%dumpFMIModelVariableVariability(variability)%><%dumpFMIModelVariableCausality(causality)%><%baseType%> <%name%><%dumpFMIBooleanModelVariableStartValue(hasStartValue, startValue, isFixed)%><%dumpFMIModelVariableDescription(description)%>;
  >>
case STRINGVARIABLE(__) then
  <<
  <%dumpFMIModelVariableVariability(variability)%><%dumpFMIModelVariableCausality(causality)%><%baseType%> <%name%><%dumpFMIStringModelVariableStartValue(hasStartValue, startValue, isFixed)%><%dumpFMIModelVariableDescription(description)%>;
  >>
case ENUMERATIONVARIABLE(__) then
  <<
  <%dumpFMIModelVariableVariability(variability)%><%dumpFMIModelVariableCausality(causality)%><%baseType%> <%name%><%dumpFMIIntegerModelVariableStartValue(hasStartValue, startValue, isFixed)%><%dumpFMIModelVariableDescription(description)%>;
  >>
end dumpFMIModelVariable;

template dumpFMIModelVariableVariability(String variability)
::=
  <<
  <%if stringEq(variability, "") then "" else variability+" "%>
  >>
end dumpFMIModelVariableVariability;

template dumpFMIModelVariableCausality(String causality)
::=
  <<
  <%if stringEq(causality, "") then "" else causality+" "%>
  >>
end dumpFMIModelVariableCausality;

template dumpFMIRealModelVariableStartValue(Boolean hasStartValue, Real startValue, Boolean isFixed)
::=
  <<
  <%if hasStartValue then "(start="+startValue%><%if boolAnd(hasStartValue,isFixed) then ",fixed=true"%><%if boolAnd(boolNot(hasStartValue),isFixed) then "(fixed=true"%><%if boolOr(hasStartValue,isFixed) then ")"%>
  >>
end dumpFMIRealModelVariableStartValue;

template dumpFMIIntegerModelVariableStartValue(Boolean hasStartValue, Integer startValue, Boolean isFixed)
::=
  <<
  <%if hasStartValue then "(start="+startValue%><%if boolAnd(hasStartValue,isFixed) then ",fixed=true"%><%if boolAnd(boolNot(hasStartValue),isFixed) then "(fixed=true"%><%if boolOr(hasStartValue,isFixed) then ")"%>
  >>
end dumpFMIIntegerModelVariableStartValue;

template dumpFMIBooleanModelVariableStartValue(Boolean hasStartValue, Boolean startValue, Boolean isFixed)
::=
  <<
  <%if hasStartValue then "(start="+startValue%><%if boolAnd(hasStartValue,isFixed) then ",fixed=true"%><%if boolAnd(boolNot(hasStartValue),isFixed) then "(fixed=true"%><%if boolOr(hasStartValue,isFixed) then ")"%>
  >>
end dumpFMIBooleanModelVariableStartValue;

template dumpFMIStringModelVariableStartValue(Boolean hasStartValue, String startValue, Boolean isFixed)
::=
  <<
  <%if hasStartValue then "(start=\""+startValue+"\""%><%if boolAnd(hasStartValue,isFixed) then ",fixed=true"%><%if boolAnd(boolNot(hasStartValue),isFixed) then "(fixed=true"%><%if boolOr(hasStartValue,isFixed) then ")"%>
  >>
end dumpFMIStringModelVariableStartValue;

template dumpFMIModelVariableDescription(String description)
::=
  <<
  <%if stringEq(description, "") then "" else " \""+description+"\""%>
  >>
end dumpFMIModelVariableDescription;

template dumpRealVariablesVR(list<ModelVariables> fmiModelVariablesList)
 "Generates the Model Variables value reference arrays."
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpRealVariableVR(fmiModelVariable) ;separator=", "%>
  >>
end dumpRealVariablesVR;

template dumpRealVariableVR(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case REALVARIABLE(variability = "") then
  <<
  <%valueReference%>
  >>
end dumpRealVariableVR;

template dumpIntegerVariablesVR(list<ModelVariables> fmiModelVariablesList)
 "Generates the Model Variables value reference arrays."
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpIntegerVariableVR(fmiModelVariable) ;separator=", "%>
  >>
end dumpIntegerVariablesVR;

template dumpIntegerVariableVR(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case INTEGERVARIABLE(variability = "") then
  <<
  <%valueReference%>
  >>
end dumpIntegerVariableVR;

template dumpBooleanVariablesVR(list<ModelVariables> fmiModelVariablesList)
 "Generates the Model Variables value reference arrays."
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpBooleanVariableVR(fmiModelVariable) ;separator=", "%>
  >>
end dumpBooleanVariablesVR;

template dumpBooleanVariableVR(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case BOOLEANVARIABLE(variability = "") then
  <<
  <%valueReference%>
  >>
end dumpBooleanVariableVR;

template dumpStringVariablesVR(list<ModelVariables> fmiModelVariablesList)
 "Generates the Model Variables value reference arrays."
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStringVariableVR(fmiModelVariable) ;separator=", "%>
  >>
end dumpStringVariablesVR;

template dumpStringVariableVR(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case STRINGVARIABLE(variability = "") then
  <<
  <%valueReference%>
  >>
end dumpStringVariableVR;

template dumpStartRealVariablesValueReference(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartRealVariableValueReference(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartRealVariablesValueReference;

template dumpStartRealVariableValueReference(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case REALVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%valueReference%>
  >>
end dumpStartRealVariableValueReference;

template dumpStartRealVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartRealVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartRealVariablesName;

template dumpStartRealVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case REALVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%name%>
  >>
end dumpStartRealVariableName;

template dumpStartIntegerVariablesValueReference(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartIntegerVariableValueReference(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartIntegerVariablesValueReference;

template dumpStartIntegerVariableValueReference(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case INTEGERVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%valueReference%>
  >>
end dumpStartIntegerVariableValueReference;

template dumpStartIntegerVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartIntegerVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartIntegerVariablesName;

template dumpStartIntegerVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case INTEGERVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%name%>
  >>
end dumpStartIntegerVariableName;

template dumpStartBooleanVariablesValueReference(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartBooleanVariableValueReference(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartBooleanVariablesValueReference;

template dumpStartBooleanVariableValueReference(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case BOOLEANVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%valueReference%>
  >>
end dumpStartBooleanVariableValueReference;

template dumpStartBooleanVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartBooleanVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartBooleanVariablesName;

template dumpStartBooleanVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case BOOLEANVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%name%>
  >>
end dumpStartBooleanVariableName;

template dumpStartStringVariablesValueReference(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartStringVariableValueReference(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartStringVariablesValueReference;

template dumpStartStringVariableValueReference(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case STRINGVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%valueReference%>
  >>
end dumpStartStringVariableValueReference;

template dumpStartStringVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStartStringVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpStartStringVariablesName;

template dumpStartStringVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case STRINGVARIABLE(hasStartValue = true, isFixed = false) then
  <<
  <%name%>
  >>
end dumpStartStringVariableName;

template dumpRealVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpRealVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpRealVariablesName;

template dumpRealVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case REALVARIABLE(variability = "") then
  <<
  <%name%>
  >>
end dumpRealVariableName;

template dumpIntegerVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpIntegerVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpIntegerVariablesName;

template dumpIntegerVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case INTEGERVARIABLE(variability = "") then
  <<
  <%name%>
  >>
end dumpIntegerVariableName;

template dumpBooleanVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpBooleanVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpBooleanVariablesName;

template dumpBooleanVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case BOOLEANVARIABLE(variability = "") then
  <<
  <%name%>
  >>
end dumpBooleanVariableName;

template dumpStringVariablesName(list<ModelVariables> fmiModelVariablesList)
::=
  <<
  <%fmiModelVariablesList |> fmiModelVariable => dumpStringVariableName(fmiModelVariable) ;separator=", "%>
  >>
end dumpStringVariablesName;

template dumpStringVariableName(ModelVariables fmiModelVariable)
::=
match fmiModelVariable
case STRINGVARIABLE(variability = "") then
  <<
  <%name%>
  >>
end dumpStringVariableName;

end CodegenFMU;

// vim: filetype=susan sw=2 sts=2