/*

  Copyright 2017 Loopring Project Ltd (Loopring Foundation).

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/
pragma solidity 0.5.7;
pragma experimental ABIEncoderV2;

import "../iface/IAuction.sol";
import "../iface/IAuctionData.sol";
import "../iface/ICurve.sol";

import "../lib/ERC20SafeTransfer.sol";
import "../lib/ERC20.sol";
import "../lib/MathUint.sol";

import "./libauction/AuctionBalance.sol";
import "./libauction/AuctionBids.sol";
import "./libauction/AuctionAsks.sol";
import "./libauction/AuctionInfo.sol";

/// @title An Implementation of ICurve.
/// @author Daniel Wang  - <daniel@loopring.org>
contract Auction is IAuction
{
    using MathUint          for uint;
    using MathUint          for uint32;
    using AuctionBalance    for IAuctionData.State;
    using AuctionBids       for IAuctionData.State;
    using AuctionAsks       for IAuctionData.State;
    using AuctionInfo       for IAuctionData.State;

    modifier onlyOedax {
      require (msg.sender == address(state.oedax));
      _;
    }

    // -- Constructor --
    constructor(
        address _oedax,
        uint    _auctionId,
        address _curve,
        address _askToken,
        address _bidToken,
        uint    _initialAskAmount,
        uint    _initialBidAmount,
        uint32  _P, // target price
        uint32  _S, // price scale
        uint8   _M, // price factor
        uint    _T
        )
        public
    {

        require(_oedax != address(0x0));
        require(_auctionId > 0);
        require(_curve != address(0x0));
        require(_askToken != address(0x0) || _bidToken != address(0x0));

        require(_P > 0);
        require(_M > 0);
        require(_P / _M > 0, "zero min price");
        require(_T % 3600 == 0, "duration must be in hour");
        require(_T / 3600 > 0 && _T / 3600 <= 30 * 24, "invalid duration");

        owner = msg.sender; // creator

        state.oedax = IOedax(_oedax);
        state.curve = ICurve(_curve);

        state.auctionId = _auctionId;
        state.askToken = _askToken;
        state.bidToken = _bidToken;
        state.initialAskAmount = _initialAskAmount;
        state.askAmount = _initialAskAmount;
        state.initialBidAmount = _initialBidAmount;
        state.bidAmount = _initialBidAmount;
        state.startTime = block.timestamp;
        state.P = _P;
        state.S = _S;
        state.M = _M;
        state.T = _T ;
        // initTransfers();
    }

    // == Public & External Functions ==

    function()
        external
        payable
    {
        if (state.bidToken == address(0x0)) {
            state.bid(msg.value);
        } else if (state.askToken == address(0x0)) {
            state.ask(msg.value);
        } else {
            revert();
        }
    }

    function bid(uint amount)
        public
        returns(
            uint  _amount,
            uint  _queued,
            IAuctionData.Info memory i
        )
    {
        uint a = state.depositToken(
            state.bidToken,
            amount
        );
        return state.bid(a);
    }

    function ask(uint amount)
        public
        returns(
            uint  _amount,
            uint  _queued,
            IAuctionData.Info memory i
        )
    {
        uint a = state.depositToken(
            state.askToken,
            amount
        );
        return state.ask(a);
    }

    function getAuctionInfo()
        public
        view
        returns (IAuctionData.Info memory)
    {
        return state.getAuctionInfo();
    }

    function getBalance(address user)
        internal
        view
        returns (
            IAuctionData.Balance memory bidBalance,
            IAuctionData.Balance memory askBalance
        )
    {
        return state.getBalance(user);
    }

    // == Internal & Private Functions ==
}