//  Zone Token Burner Contract by Zone.game team
//  Author:  Kodiswaran Babu Janardhanan
//  Compiled using @reach-sh/stdlib 0.1.8-rc.9
//  Reach Hashes: reach: 85500c11,reach-cli: 85500c11,react-runner: 85500c11,rpc-server: 85500c11,runner: 85500c11,devnet-algo: 85500c11
//  Released on : Feb 13th, 2022
'reach 0.1';

export const main = Reach.App(() => {

  const Common = {
    ...hasConsoleLogger,
    showCtcInfo: Fun([Contract], Null),
    showAddress: Fun([Address], Null),  
  };
  const Deployer = Participant('Deployer',{ 
    ...Common,
    getTokens: Fun([],Tuple(UInt,UInt,Token)),
    ready: Fun([],Null)
  });

  const view = View('Zone_Burn_States', {
    totalDeposited: UInt,
  });

  const api = API('contractAPI', {
    deposit:  Fun([UInt,UInt], Bool)
  });
  const E = Events('Zone_Burn_Events', {
    deposited: [Address,UInt,UInt],
    exit:[],
  });
  init();
  Deployer.publish();
  const addr = getAddress();
  const info = getContract();

  Deployer.only(() => {
        interact.showCtcInfo(info);
        interact.showAddress(addr);
        const [algoSupply,zoneSupply,zoneToken] = declassify(interact.getTokens());
  })
  commit();
  Deployer.publish(algoSupply,zoneSupply,zoneToken)
  commit();
   
  Deployer.pay([algoSupply,[zoneSupply,zoneToken]]);
  Deployer.interact.ready();

  const [totalAlgoDeposited, totalZoneDeposited] = parallelReduce([
    algoSupply,zoneSupply
  ])
  .define(() => {
    view.totalDeposited.set(totalZoneDeposited);
  })
  .invariant(
      totalZoneDeposited === balance(zoneToken)
  )
  .while(true)      // Infinite loop and no option to exit out of the loop
  .paySpec([zoneToken])  // Only one API to get the deposits for zoneToken to burn and algos for fees if any 
  .api(
    api.deposit,
    (algoAmt,zoneAmount) => {
      assume(algoAmt >= 0 && zoneAmount >=0 );
    },
    (algoAmt,zoneAmount) => [algoAmt, [zoneAmount, zoneToken]],
    (algoAmt,zoneAmount, depositResult) => {
      require(algoAmt >= 0 && zoneAmount >=0);
      depositResult(algoAmt >= 0 && zoneAmount >=0);
      E.deposited(this,algoAmt,zoneAmount);      
      return [totalAlgoDeposited+algoAmt,totalZoneDeposited+zoneAmount];
    }
  )
  commit();
  assert(false);
  Deployer.publish();
  transfer(balance(zoneToken),zoneToken).to(Deployer);  // Needed for token linearity check
  transfer(balance()).to(Deployer);  // Needed for token linearity check
  assert(balance(zoneToken) === 0);
  assert(balance() === 0)
  E.exit();
  commit();
  exit();
});
