// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Streamer is Ownable {
  event Opened(address, uint256);
  event Challenged(address);
  event Withdrawn(address, uint256);
  event Closed(address);

  mapping(address => uint256) balances;
  mapping(address => uint256) canCloseAt;

  function fundChannel() public payable {
    /*
      Checkpoint 2: fund a channel

      Complete this function so that it:
      - reverts if msg.sender already has a running channel (ie, if balances[msg.sender] != 0)
      - updates the balances mapping with the eth received in the function call
      - emits an Opened event
    */
   require(msg.value > 0, "send some eth");
   if(balances[msg.sender] != 0){
    revert("channel already open");
    
   }
    balances[msg.sender] = msg.value;
    emit Opened(msg.sender, balances[msg.sender]);
   
  }

  function timeLeft(address channel) public view returns (uint256) {
    if (canCloseAt[channel] == 0 || canCloseAt[channel] < block.timestamp) {
      return 0;
    }

    return canCloseAt[channel] - block.timestamp;
  }

  function withdrawEarnings(Voucher calldata voucher) public {
    // like the off-chain code, signatures are applied to the hash of the data
    // instead of the raw data itself
    bytes32 hashed = keccak256(abi.encode(voucher.updatedBalance));

    // The prefix string here is part of a convention used in ethereum for signing
    // and verification of off-chain messages. The trailing 32 refers to the 32 byte
    // length of the attached hash message.
    //
    // There are seemingly extra steps here compared to what was done in the off-chain
    // `reimburseService` and `processVoucher`. Note that those ethers signing and verification
    // functions do the same under the hood.
    //
    // see https://blog.ricmoo.com/verifying-messages-in-solidity-50a94f82b2ca
    bytes memory prefixed = abi.encodePacked("\x19Ethereum Signed Message:\n32", hashed);
    bytes32 prefixedHashed = keccak256(prefixed);

    /*
      Checkpoint 4: Recover earnings

      The service provider would like to cash out their hard earned ether.
          - use ecrecover on prefixedHashed and the supplied signature
          - require that the recovered signer has a running channel with balances[signer] > v.updatedBalance
          - calculate the payment when reducing balances[signer] to v.updatedBalance
          - adjust the channel balance, and pay the Guru(Contract owner). Get the owner address with the `owner()` function.
          - emit the Withdrawn event
    */
   // Step 3: Recover the signer's address using ecrecover
    address signer = ecrecover(prefixedHashed, voucher.sig.v, voucher.sig.r, voucher.sig.s);

    // Step 4: Check if the signer has a running channel with sufficient balances
    require(balances[signer] > voucher.updatedBalance, "Insufficient funds");

    // Step 5: Calculate the payment when reducing balances to voucher.updatedBalance
    uint256 payment = balances[signer] - voucher.updatedBalance;

    // Step 6: Adjust the channel balance
    balances[signer] = voucher.updatedBalance;

    // Step 7: Pay the contract owner (Guru) and get the owner address with the 'owner()' function
    payable(owner()).transfer(payment);

    // Step 8: Emit the Withdrawn event
    emit Withdrawn(signer, payment);
  }

  /*
    Checkpoint 5a: Challenge the channel

    Create a public challengeChannel() function that:
    - checks that msg.sender has an open channel
    - updates canCloseAt[msg.sender] to some future time
    - emits a Challenged event
  */
 function challengeChannel() public {
    // Step 1: Check that msg.sender has an open channel (You need to define how you identify an open channel)
    require(balances[msg.sender] != 0, "No open channel found");

    // Step 2: Set a future time for canCloseAt[msg.sender]
    // This can be achieved by adding a predefined time duration to the current block timestamp.
    // For example, to set it to 24 hours in the future:
    canCloseAt[msg.sender] = block.timestamp + 60 seconds;

    // Step 3: Emit the Challenged event
    emit Challenged(msg.sender);
}

  /*
    Checkpoint 5b: Close the channel

    Create a public defundChannel() function that:
    - checks that msg.sender has a closing channel
    - checks that the current time is later than the closing time
    - sends the channel's remaining funds to msg.sender, and sets the balance to 0
    - emits the Closed event
  */
 function defundChannel() public {
    // Step 1: Check that msg.sender has a closing channel (You need to define how you identify a closing channel).
    // Step 2: Check that the current time is later than the closing time.
    require(canCloseAt[msg.sender] > 0 && canCloseAt[msg.sender] <= block.timestamp, "Channel not eligible for defunding");

    // Step 3: Send the channel's remaining funds to msg.sender and set the balance to 0.
    uint256 remainingFunds = balances[msg.sender];
    require(remainingFunds > 0, "No funds to defund");
    
    balances[msg.sender] = 0;
    payable(msg.sender).transfer(remainingFunds);

    // Step 4: Emit the Closed event
    emit Closed(msg.sender);
}

  struct Voucher {
    uint256 updatedBalance;
    Signature sig;
  }
  struct Signature {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }
}
