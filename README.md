# Fantom CrossChain Bridge
Repository implements cross-chain bridge with distributed transactions validation. The purpose of the Bridge is to allow users to easily and securely transfer their ERC20 assets between Eth compatible networks, especially the one and only Ethereum main net, and Fantom Opera network.

The Bridge architecture consists of following elements:
 - An Input Contract, deployed on all participating chains. The contract captures input transactions and signals transfer requests. 
 - A Pool Contract, deployed on all participating chains. It's responsible for controlling pool of assets releasing them to recipients upon receiving verified and signed transfer orders.
 - A network of validator nodes connected to all the participating networks and monitoring input contracts for transfer request. Validators check authenticity of received transfer requests and after processing a signature collecting procedure among them, they initiate assets release by sending the Pool contract appropriate transfer orders.
 - A Management Contract, deployed on Fantom Opera network. The management contract is responsible for keeping track of approved validators and is responsible for controlling the bridge economy and security.
 
 Please note, the Input and Pool contracts are actually implemented as a single contract.  
 