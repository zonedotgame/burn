# Burn Zone Tokens
The repo has the contract for burning zone tokens in algorand block chain and the contract code is explained in this readme file.

Algorand block chain does not provide any burning mechanism for its tokens, the only way to do this is to freeze the token in a smart contract where withdrawal or transfer operations are not possible from the smart contract application account.  At Zone, we implemented this much needed smart contract using Reach:The Safest and Easiest DApp Programming Language.  You can study more about this language here(https://docs.reach.sh).  For all the syntax in this Dapp, please refer to Reach doc.

I have fragmented the smart contract application into 4 segments here, first segment shows how to declare the necessary participants, read only view states that are needed and the events that will be generated from the smart contract and finally to deploy these by calling init(). As you can see we just need only one participant to supply the tokens that needs to be burnt or locked into this Dapp, so i have defined Deployer as a participant and it has 5 interfaces which follows here.  First interface, is the default console logger, the first one in the common interace to log anything from the contract to the Dapp client/Dapp frontend application.  The second interace is showCtcInfo, to show the the Dapp/application Id to the client application.  The third interace is showAddress to show Dapp application account address.  The fourth interface can take the initial algo amount for the contract to pay any fees (if any) and zone token amount (if any) to be burnt.  The fifth interface is to signal that the contract is ready to accept API calls from now on.

export const main = Reach.App(() => {

  const Common = {
    ...hasConsoleLogger,
    showCtcInfo: Fun([Contract], Null),  // Show application Id
    showAddress: Fun([Address], Null),   // Show applciation account address
  };
  const Deployer = Participant('Deployer',{ 
    ...Common,
    getTokens: Fun([],Tuple(UInt,UInt,Token)),  // Deployer provides algosAmount,zoneTokenAmount and zoneToken ASA Id to the contract to pay to the contract on deployment
    ready: Fun([],Null)  // Interface for synchron
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

The second segment is to show the contract deployment details to the Dapp frontend using deployer participant interfaces discussed above, to collect the initial amounts from the deployer account, to publish on chain the amounts and token opted into the contract and finally to pay the amounts to the contract and signal the frontend that now contract is ready to receive the API calls.

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
   
  Deployer.pay([algoSupply,[zoneSupply,zoneToken]]);  // Pay to the contract both algoAmount and zoneToken Amount
  Deployer.interact.ready();  // Signal Frontend that it is ready to receive the API calls.

In third segment we run a parallel reduce infinite loop to receive API calls for deposit to burn the deposited zone tokens and algos for any fees. After receiving the deposit, the logic also emits an deposited event. The loop invariant is to check whether total deposited zone token should always match the balance of the zone token in the application account.  I would highly recommend to read the Reach doc about this parallel reduce loop syntax.

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

The last segment implements the assertion that the execution should not reach here at any point in time and also obeys the token linerality rule in Reach that contract must always transfer all the funds to one address and then exit.  In our case, the above infinite loop will never exit and come to this segment and at the same time, we should make the contract compile in Reach following the token linearity rule.  So, we implement these logic to assert false and come out in case if the exeuction ends up here, transfer all the application account balances to the deployer, emit an exit event and exit the contract.  

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

I hope i have explained enough to make you understand how we have implemented our burn smart contract logic for zone tokens using Reach programming language.  I have deployed this contract in algorand MainNet and its application ID is 603436353 and the contract application account address is YBQAVRYO6MOB366VDPT4PMAUFMC2AFN47F465DJ65ET5MTO3LBRZIYL7EQ.  I am happy to receive your feedback comments on this article below.

