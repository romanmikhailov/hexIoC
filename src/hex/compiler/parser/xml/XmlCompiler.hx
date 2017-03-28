package hex.compiler.parser.xml;

import hex.core.IApplicationAssembler;

#if macro
import haxe.macro.Expr;
import hex.compiler.core.CompileTimeContextFactory;
import hex.compiletime.CompileTimeApplicationAssembler;
import hex.compiletime.CompileTimeParser;
import hex.compiletime.util.ClassImportHelper;
import hex.compiletime.xml.DSLReader;
import hex.compiletime.xml.ExceptionReporter;
import hex.compiletime.basic.CompileTimeApplicationContext;
import hex.preprocess.ConditionalVariablesChecker;
import hex.preprocess.MacroConditionalVariablesProcessor;

using StringTools;
#end

/**
 * ...
 * @author Francis Bourre
 */
class XmlCompiler
{
	#if macro
	static function _readXmlFile( fileName : String, ?preprocessingVariables : Expr, ?conditionalVariables : Expr, ?applicationAssemblerExpr : Expr, ?applicationContextName : String ) : ExprOf<IApplicationAssembler>
	{
		var conditionalVariablesMap 	= MacroConditionalVariablesProcessor.parse( conditionalVariables );
		var conditionalVariablesChecker = new ConditionalVariablesChecker( conditionalVariablesMap );
		
		var dslReader					= new DSLReader();
		var document 					= dslReader.read( fileName, preprocessingVariables, conditionalVariablesChecker );
		
		var assembler 					= new CompileTimeApplicationAssembler( applicationAssemblerExpr );
		var parser 						= new CompileTimeParser( new ParserCollection() );
		
		parser.setImportHelper( new ClassImportHelper() );
		parser.setExceptionReporter( new ExceptionReporter( dslReader.positionTracker ) );
		parser.parse( assembler, document, CompileTimeContextFactory, CompileTimeApplicationContext, applicationContextName );

		return assembler.getMainExpression();
	}
	#end
	
	macro public static function compile( fileName : String, ?preprocessingVariables : Expr, ?conditionalVariables : Expr, ?applicationContextName : String ) : ExprOf<IApplicationAssembler>
	{
		return XmlCompiler._readXmlFile( fileName, preprocessingVariables, conditionalVariables, applicationContextName );
	}
	
	macro public static function compileWithAssembler( assemblerExpr : Expr, fileName : String, ?preprocessingVariables : Expr, ?conditionalVariables : Expr, ?applicationContextName : String ) : ExprOf<IApplicationAssembler>
	{
		return XmlCompiler._readXmlFile( fileName, preprocessingVariables, conditionalVariables, assemblerExpr, applicationContextName );
	}
}
