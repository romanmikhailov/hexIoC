package hex.compiler.factory;

#if macro
import haxe.macro.Expr;
import hex.compiler.vo.FactoryVO;
import hex.error.Exception;
import hex.error.PrivateConstructorException;
import hex.ioc.vo.ConstructorVO;

/**
 * ...
 * @author Francis Bourre
 */
class FunctionFactory
{
	/** @private */
    function new()
    {
        throw new PrivateConstructorException();
    }

	static public function build( factoryVO : FactoryVO ) : Expr
	{
		var constructorVO 	= factoryVO.constructorVO;
		var coreFactory		= factoryVO.contextFactory.getCoreFactory();

		var method : Dynamic;
		var msg : String;

		var args 				= constructorVO.arguments[ 0 ].split(".");
		var targetID : String 	= args[ 0 ];
		var path 				= args.slice( 1 ).join( "." );

		if ( !coreFactory.isRegisteredWithKey( targetID ) )
		{
			factoryVO.contextFactory.buildObject( targetID );
		}

		var target = coreFactory.locate( targetID );

		try
		{
			method = coreFactory.fastEvalFromTarget( target, path );

		} catch ( error : Dynamic )
		{
			msg = "FunctionFactory.build() failed on " + target + " with id '" + targetID + "'. ";
			msg += path + " method can't be found.";
			throw new Exception( msg );
		}
		
		return method;
	}
}
#end