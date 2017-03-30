package hex.compiler.parser.xml;
import hex.compiletime.xml.AbstractXmlParser;
import hex.factory.BuildRequest;

#if macro
import hex.compiletime.ICompileTimeApplicationAssembler;
import hex.metadata.IAnnotationProvider;
import hex.util.MacroUtil;

/**
 * ...
 * @author Francis Bourre
 */
class Launcher extends AbstractXmlParser<BuildRequest>
{
	public function new() 
	{
		super();
	}
	
	override public function parse() : Void
	{
		var assembler : ICompileTimeApplicationAssembler = cast this._applicationAssembler;
		
		//Dispatch CONTEXT_PARSED message
		var messageType = MacroUtil.getStaticVariable( "hex.core.ApplicationAssemblerMessage.CONTEXT_PARSED" );
		assembler.addExpression( macro @:mergeBlock { applicationContext.dispatch( $messageType ); } );

		//Create applicationcontext injector
		assembler.addExpression( macro @:mergeBlock { var __applicationContextInjector = applicationContext.getInjector(); } );

		//Create runtime coreFactory
		assembler.addExpression( macro @:mergeBlock { var coreFactory = applicationContext.getCoreFactory(); } );
		
		var pack = MacroUtil.getPack( Type.getClassName( IAnnotationProvider ) );
		assembler.addExpression( macro @:mergeBlock { var __annotationProvider = __applicationContextInjector.getInstance( $p { pack } ); } );

		//build
		assembler.buildEverything();
		
		//return program
		assembler.addExpression( assembler.getAssemblerExpression() );
	}
}
#end