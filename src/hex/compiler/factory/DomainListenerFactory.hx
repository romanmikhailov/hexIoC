package hex.compiler.factory;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.ClassType;
import hex.domain.ApplicationDomainDispatcher;
import hex.domain.Domain;
import hex.domain.DomainUtil;
import hex.event.ClassAdapter;
import hex.event.EventProxy;
import hex.event.IObservable;
import hex.ioc.vo.DomainListenerVO;
import hex.ioc.vo.DomainListenerVOArguments;
import hex.ioc.vo.FactoryVO;
import hex.util.MacroUtil;

/**
 * ...
 * @author Francis Bourre
 */
class DomainListenerFactory
{
	function new()
	{

	}
	
	#if macro
	static var _domainLocator 		: Map<String, String> = new Map();
	static var _eventProxyClassType : ClassType = MacroUtil.getClassType( Type.getClassName( EventProxy ) );
	static var _observableInterface : ClassType = MacroUtil.getClassType( Type.getClassName( IObservable ) );
	
	static function _getDomain( domainName : String, factoryVO : FactoryVO ) : String
	{
		if ( factoryVO.domainLocator.exists( domainName ) )
		{
			return factoryVO.domainLocator.get( domainName );
		}
		else
		{
			var DomainUtilClass = MacroUtil.getPack( Type.getClassName( DomainUtil )  );
			var DomainClass 	= MacroUtil.getPack( Type.getClassName( Domain )  );
			var domainVariable 	= "__domainName_" + domainName;
			
			factoryVO.expressions.push( macro @:mergeBlock 
				{ 
					var $domainVariable = $p { DomainUtilClass }.getDomain( $v{ domainName }, $p { DomainClass } ); 
				} );
			
			factoryVO.domainLocator.set( domainName, domainVariable );
			return domainVariable;
		}
	}
	
	static function _getClassTypeFromNewBlockExpression( e : Expr ) : ClassType
	{
		var className : String = "";
		
		if ( e != null )
		{
			switch ( e.expr )
			{
				case EBlock( expr ):
					
					switch( expr[0].expr )
					{
						case ENew( t, params ):
							className = t.pack.join( "." ) + "." + t.name;
							
						default:
							return null;
					}
					
				default:
					return null;
			}

			return MacroUtil.getClassType( className );
		}
		else
		{
			return null;
		}
	}
	
	static function isEventProxy( e : Expr ) : Bool
	{
		var classType = DomainListenerFactory._getClassTypeFromNewBlockExpression( e );
		return classType != null ? MacroUtil.isSameClass( classType, DomainListenerFactory._eventProxyClassType ) || MacroUtil.isSubClassOf( classType, DomainListenerFactory._eventProxyClassType ) : false;
	}
	
	static function isObservable( e : Expr ) : Bool
	{
		var classType = DomainListenerFactory._getClassTypeFromNewBlockExpression( e );
		return classType != null ? MacroUtil.implementsInterface( classType, DomainListenerFactory._observableInterface ) : false;
	}
	
	static public function build( factoryVO : FactoryVO, domainListener : DomainListenerVO ) : Dynamic
	{
		var ApplicationDomainDispatcherClass = MacroUtil.getPack( Type.getClassName( ApplicationDomainDispatcher )  );
		var DomainUtilClass = MacroUtil.getPack( Type.getClassName( DomainUtil )  );
		var DomainClass = MacroUtil.getPack( Type.getClassName( Domain )  );
		
		var args : Array<DomainListenerVOArguments> = domainListener.arguments;

		if ( args != null && args.length > 0 )
		{
			for ( domainListenerArgument in args )
			{
				var method = DomainListenerFactory.isEventProxy( factoryVO.coreFactory.locate( domainListener.ownerID ) ) ? "handleCallback" : domainListenerArgument.method;

				if ( method != null || domainListenerArgument.strategy != null )
				{
					var listenerID 			= domainListener.ownerID;
					var listenerVar 		= macro $i{ listenerID };
					var listenedDomainName 	= domainListener.listenedDomainName;
					var messageType 		= MacroUtil.getStaticVariable( domainListenerArgument.staticRef, domainListenerArgument.filePosition );
					var strategyClassName 	= domainListenerArgument.strategy;
					
					if ( !factoryVO.coreFactory.isRegisteredWithKey( listenedDomainName ) )
					{
						Context.error( "Domain '" + listenedDomainName + "' not found in applicationContext named '" + 
						factoryVO.contextFactory.getApplicationContext().getName() + "'", domainListener.filePosition );
					}
					var listenedDomain		= factoryVO.coreFactory.locate( listenedDomainName );

					if ( strategyClassName != null )
					{
						var StrategyClass = MacroUtil.getPack( strategyClassName );
						var ClassAdapterClass = MacroUtil.getTypePath( Type.getClassName( ClassAdapter ) );
						
						var adapterVarName = "__adapterFor__" + listenedDomainName + "__" + ( domainListenerArgument.staticRef.split( "." ).join( "_" ) );
						factoryVO.expressions.push( macro @:mergeBlock { var $adapterVarName = new $ClassAdapterClass(); } );
						var adapterVar = macro $i { adapterVarName };
						
						if ( method != null )
						{
							factoryVO.expressions.push( macro @:mergeBlock { $adapterVar.setCallBackMethod( $listenerVar, $listenerVar.$method ); } );
						}

						factoryVO.expressions.push( macro @:mergeBlock { $adapterVar.setAdapterClass( $p { StrategyClass } ); } );
						factoryVO.expressions.push( macro @:mergeBlock { $adapterVar.setAnnotationProvider( __annotationProvider ); } );

						if ( domainListenerArgument.injectedInModule && factoryVO.moduleLocator.isRegisteredWithKey( listenerID ) )
						{
							factoryVO.expressions.push( macro @:mergeBlock 
							{ 
								$adapterVar.setFactoryMethod( $listenerVar.getInjector(), $listenerVar.getInjector().instantiateUnmapped ); 
							} );
						}
						else 
						{
							factoryVO.expressions.push( macro @:mergeBlock 
							{ 
								$adapterVar.setFactoryMethod( __applicationContextInjector, __applicationContextInjector.instantiateUnmapped ); 
							} );
						}
						
						var adapterExp = macro { Reflect.makeVarArgs( function( rest : Array<Dynamic> ) : Void { ( $adapterVar.getCallbackAdapter() )( rest ); } ); };
						
						if ( DomainListenerFactory.isObservable( listenedDomain ) )
						{
							var dispatcherVar = macro $i{ listenedDomainName };
							factoryVO.expressions.push( macro @:mergeBlock { $dispatcherVar.addHandler( $messageType, $listenerVar, $adapterExp ); } );
						}
						else
						{
							var domainVar = macro $i { DomainListenerFactory._getDomain( listenedDomainName, factoryVO ) };
							factoryVO.expressions.push( macro @:mergeBlock 
							{ 
								$p { ApplicationDomainDispatcherClass } .getInstance()
								.addHandler( $messageType, $listenerVar, $adapterExp, $domainVar ); 
							} );
						}
					}
					else
					{
						if ( DomainListenerFactory.isObservable( listenedDomain ) )
						{
							var dispatcherVar = macro @:pos( domainListenerArgument.filePosition ) $i{ listenedDomainName };
							factoryVO.expressions.push( macro @:mergeBlock 
							{ 
								$dispatcherVar.addHandler( $messageType, $listenerVar, $listenerVar.$method ); 
							} );
						}
						else
						{
							var domainVar = macro $i { DomainListenerFactory._getDomain( listenedDomainName, factoryVO ) };
							var messageType = MacroUtil.getStaticVariable( domainListenerArgument.staticRef, domainListenerArgument.filePosition );
							factoryVO.expressions.push( macro @:pos( domainListenerArgument.filePosition ) @:mergeBlock { $p { ApplicationDomainDispatcherClass } .getInstance().addHandler( $messageType, $listenerVar, $listenerVar.$method, $domainVar ); } );
						}
					}
				}
				else
				{
					if ( method == null )
					{
						Context.error( "DomainListenerFactory.build failed. Callback should be defined (use 'method' attribute) in node with '" + domainListener.ownerID + "' id", Context.currentPos() );
					}
					else
					{
						Context.error( "DomainListenerFactory.build failed. Method named '" + method + "' can't be found in node with '" + domainListener.ownerID + "' id", Context.currentPos() );
					}
				}
			}

			return true;

		} else
		{
			var listenerID = domainListener.ownerID;
			var listenedDomainName = domainListener.listenedDomainName;
			var extVar = macro $i{ listenerID };

			var domainVar = macro $i { DomainListenerFactory._getDomain( listenedDomainName, factoryVO ) };
			factoryVO.expressions.push( macro @:mergeBlock { $p { ApplicationDomainDispatcherClass }.getInstance().addListener( $extVar, $domainVar ); } );

			return true;
		}
	}
	#end
}