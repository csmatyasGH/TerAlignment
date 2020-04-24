/*************************************************************************************************
 * Class Name   : BooleanExpression
 * Created Date : July 4, 2018
 * Author       : Vijaya Sankar N
 * Description  : Class to evaluate a boolean expression
 * Example      : (TRUE AND (FALSE OR TRUE)) is TRUE
   '(FALSE OR ((TRUE OR FALSE) AND (TRUE OR FALSE)))'
   '(FALSE AND ((TRUE OR FALSE) AND (TRUE OR FALSE)))'

   We will ue it  in Validating HUB Territory Allocator
 *************************************************************************************************/
public class BooleanExpression {
  static Map<String, String> logicTypes = new Map<String, String>();
  static Map<String, Map<String, String>> expressionLogic = new Map<String, Map<String, String>>();

  /*********************************************
   * Evaluate a boolean expreassion
   *
   ********************************************/
  public static Boolean eval(String expression) {
    // If expression contains all TRUE or FALSE
    if (expression.containsNone('FALSE')) {
      return true;
    }
    if (expression.containsNone('TRUE')) {
      return false;
    }

    fillLogic(); //initialize the 2 aps

    return Boolean.valueOf(evaluateExpression(expression.toUpperCase()));
  }

  /*********************************************************
it is a recursive method which call itself as long as it
still contain AND/OR  or BRACE  character/

logicTypes.put('AND', 'AND');
logicTypes.put('OR', 'OR');
logicTypes.put('(', 'BRACES');
*********************************************************/
  public static String evaluateExpression(String expression) {
    for (String logicType : logicTypes.keySet()) {
      //logicType is 'OR', 'AND', '('
      if (expression.contains(logicType)) {
        expression = simplifyExpression(expression, logicTypes.get(logicType));
      }
    }

    //if expression still contains AND/OR/( call method again till we have pure TRUE/FALSE
    if (
      expression.contains('AND') ||
      expression.contains('OR') ||
      expression.contains('(')
    ) {
      expression = evaluateExpression(expression);
    }

    return expression;
  }

  /***************************************************************************
   param1 is the extression we want to evaluate
   param2 is either 'OR' , 'AND', 'BRACES'
 **************************************************************************/
  public static string simplifyExpression(String expression, String LogicType) {
    Map<String, String> Logic = new Map<String, String>(
      expressionLogic.get(LogicType)
    );
    System.Debug('CSABAX Logic map = ' + Logic);

    /****************************************
	   Logic exemple for LogicType = 'AND' looks
	   ANDLogic.put('TRUE AND TRUE', 'TRUE');
	   ANDLogic.put('TRUE AND FALSE', 'FALSE');
	   ANDLogic.put('FALSE AND TRUE', 'FALSE');
	   ANDLogic.put('FALSE AND FALSE', 'FALSE');
	****************************************/

    for (String key : Logic.keySet()) {
      //replace substring like 'TRUE AND FALSE' with 'TRUE'
      System.Debug(
        'CSABAX : key = ' +
        key +
        ' Logic.get(key) = ' +
        Logic.get(key) +
        ' expression = ' +
        expression
      );
      expression = expression.replace(key, Logic.get(key));
      System.debug('CSABAX expression = ' + expression);
    }

    return expression;
  }

  /*****************************
   Build 2  maps used in process.
*****************************/
  public static void fillLogic() {
    Map<String, String> ANDLogic = new Map<String, String>();
    Map<String, String> ORLogic = new Map<String, String>();
    Map<String, String> BRACELogic = new Map<String, String>();

    Map<String, String> NOTLogic = new Map<String, String>(); //2019.11.16.

    logicTypes.put('AND', 'AND');
    logicTypes.put('OR', 'OR');
    logicTypes.put('(', 'BRACES');
    logicTypes.put('NOT', 'BRACES'); //2019.11.20.

    // AND Logic
    ANDLogic.put('TRUE AND TRUE', 'TRUE');
    ANDLogic.put('TRUE AND FALSE', 'FALSE');
    ANDLogic.put('FALSE AND TRUE', 'FALSE');
    ANDLogic.put('FALSE AND FALSE', 'FALSE');
    expressionLogic.put('AND', ANDLogic);

    // OR Logic
    ORLogic.put('TRUE OR TRUE', 'TRUE');
    ORLogic.put('TRUE OR FALSE', 'TRUE');
    ORLogic.put('FALSE OR TRUE', 'TRUE');
    ORLogic.put('FALSE OR FALSE', 'FALSE');
    expressionLogic.put('OR', ORLogic);

    // Braces Logic
    BRACELogic.put('(TRUE)', 'TRUE');
    BRACELogic.put('(FALSE)', 'FALSE');
    BRACELogic.put('(NOT TRUE)', 'FALSE'); //2019.11.16.
    BRACELogic.put('(NOT FALSE)', 'TRUE'); //2019.11.16.
    expressionLogic.put('BRACES', BRACELogic);
  }
}