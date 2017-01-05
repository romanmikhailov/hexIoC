package hex.compiler.factory;

import hex.error.PrivateConstructorException;
import hex.ioc.vo.FactoryVO;
import hex.ioc.vo.MapVO;

/**
 * ...
 * @author Francis Bourre
 */
class MapArgumentFactory
{
	/** @private */
    function new()
    {
        throw new PrivateConstructorException( "This class can't be instantiated." );
    }

	#if macro
	static public function build( factoryVO : FactoryVO ) : Void
	{
		var factory 			= factoryVO.contextFactory;
		var constructorVO 		= factoryVO.constructorVO;
		var args : Array<MapVO>	= cast constructorVO.arguments;
		
		for ( mapVO in args )
		{
			mapVO.key 			= factory.buildVO( mapVO.getPropertyKey() );
			mapVO.value 		= factory.buildVO( mapVO.getPropertyValue() );
		}
	}
	#end
}