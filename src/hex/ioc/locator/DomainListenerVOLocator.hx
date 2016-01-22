package hex.ioc.locator;

import hex.collection.Locator;
import hex.collection.LocatorMessage;
import hex.di.IBasicInjector;
import hex.domain.Domain;
import hex.domain.DomainUtil;
import hex.error.IllegalArgumentException;
import hex.event.ClassAdapter;
import hex.event.EventProxy;
import hex.event.IAdapterStrategy;
import hex.event.MessageType;
import hex.ioc.core.BuilderFactory;
import hex.ioc.vo.DomainListenerVO;
import hex.ioc.vo.DomainListenerVOArguments;
import hex.log.Stringifier;
import hex.module.IModule;
import hex.service.IService;
import hex.service.ServiceConfiguration;

/**
 * ...
 * @author Francis Bourre
 */
class DomainListenerVOLocator extends Locator<String, DomainListenerVO>
{
	private var _builderFactory : BuilderFactory;

	public function new( builderFactory : BuilderFactory )
	{
		super();
		this._builderFactory = builderFactory;
	}
	
	public function assignAllDomainListeners() : Void
	{
		var listeners : Array<String> = this.keys();
		for ( key in listeners )
		{
			this.assignDomainListener( key );
		}
		
		this.clear();
	}

	public function assignDomainListener( id : String ) : Bool
	{
		var domainListener : DomainListenerVO 			= this.locate( id );
		var listener : Dynamic 							= this._builderFactory.getCoreFactory().locate( domainListener.ownerID );
		var args : Array<DomainListenerVOArguments> 	= domainListener.arguments;

		// Check if event provider is a service
		var service : IService<ServiceConfiguration> = null;
		if ( this._builderFactory.getCoreFactory().isRegisteredWithKey( domainListener.listenedDomainName ) )
		{
			var located : Dynamic = this._builderFactory.getCoreFactory().locate( domainListener.listenedDomainName );
			if ( Std.is( located, IService ) )
			{
				service = cast located;
			}
		}

		if ( args != null && args.length > 0 )
		{
			for ( domainListenerArgument in args )
			{
				var method : String = Std.is( listener, EventProxy ) ? "handleCallback" : domainListenerArgument.method;
				
				var messageType : MessageType = domainListenerArgument.name != null ? 
												new MessageType( domainListenerArgument.name ) : 
												this._builderFactory.getCoreFactory().getStaticReference( domainListenerArgument.staticRef );

				if ( ( method != null && Reflect.isFunction( Reflect.field( listener, method ) )) || domainListenerArgument.strategy != null )
				{
					var callback : Dynamic = domainListenerArgument.strategy != null ? this.getStrategyCallback( listener, method, domainListenerArgument.strategy, domainListenerArgument.injectedInModule ) : Reflect.field( listener, method );

					if ( service == null )
					{
						var domain : Domain = DomainUtil.getDomain( domainListener.listenedDomainName, Domain );
						this._builderFactory.getApplicationHub().addHandler( messageType, listener, callback, domain );
					}
					else
					{
						service.addHandler( messageType, listener, callback );
					}
				}
				else
				{
					if ( method == null )
					{
						throw new IllegalArgumentException( this + ".assignDomainListener failed. Callback should be defined (use 'method' attribute) in instance of '" 
															+ Stringifier.stringify( listener ) + "' class with '" + domainListener.ownerID + "' id" );
					}
					else
					{
						throw new IllegalArgumentException( this + ".assignDomainListener failed. Method named '" + method + "' can't be found in instance of '" 
															+ Stringifier.stringify( listener ) + "' class with '" + domainListener.ownerID + "' id" );
					}
				}
			}

			return true;

		} else
		{
			var domain : Domain = DomainUtil.getDomain( domainListener.listenedDomainName, Domain );
			return this._builderFactory.getApplicationHub().addListener( listener, domain );
		}
	}

	private function getStrategyCallback( listener : Dynamic, method : String, strategyClassName : String, injectedInModule : Bool = false ) : Dynamic
	{
		var callback : Dynamic 							= Reflect.field( listener, method );
		var strategyClass : Class<IAdapterStrategy> 	= cast this._builderFactory.getCoreFactory().getClassReference( strategyClassName );
		
		
		var adapter : ClassAdapter = new ClassAdapter();
		adapter.setCallBackMethod( listener, callback );
		adapter.setAdapterClass( strategyClass );
		
		if ( injectedInModule && Std.is( listener, IModule ) )
		{
			var basicInjector : IBasicInjector = listener.getBasicInjector();
			adapter.setFactoryMethod( basicInjector, basicInjector.instantiateUnmapped );
		}
		else 
		{
			adapter.setFactoryMethod( this._builderFactory.getApplicationContext().getBasicInjector(), this._builderFactory.getApplicationContext().getBasicInjector().instantiateUnmapped );
		}
		
		var f:Array<Dynamic>->Void = function( rest:Array<Dynamic> ):Void
		{
			( adapter.getCallbackAdapter() )( rest );
		}
		
		return Reflect.makeVarArgs(f);
	}
	
	override function _dispatchRegisterEvent( key : String, element : DomainListenerVO ) : Void 
	{
		this._dispatcher.dispatch( LocatorMessage.REGISTER, [key, element] );
	}
	
	override function _dispatchUnregisterEvent( key : String ) : Void 
	{
		this._dispatcher.dispatch( LocatorMessage.UNREGISTER, [key] );
	}
}