// Using ethers v5
import { ethers } from "ethers";
import "dotenv/config";
import Web3, { eth } from "web3";
import {Options} from '@layerzerolabs/lz-v2-utilities';

const ABI = [
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "uint32",
            "name": "dstEid",
            "type": "uint32"
          },
          {
            "internalType": "bytes32",
            "name": "to",
            "type": "bytes32"
          },
          {
            "internalType": "uint256",
            "name": "amountLD",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "minAmountLD",
            "type": "uint256"
          },
          {
            "internalType": "bytes",
            "name": "extraOptions",
            "type": "bytes"
          },
          {
            "internalType": "bytes",
            "name": "composeMsg",
            "type": "bytes"
          },
          {
            "internalType": "bytes",
            "name": "oftCmd",
            "type": "bytes"
          }
        ],
        "internalType": "struct SendParam",
        "name": "_sendParam",
        "type": "tuple"
      },
      {
        "internalType": "bool",
        "name": "_payInLzToken",
        "type": "bool"
      }
    ],
    "name": "quoteSend",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "nativeFee",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "lzTokenFee",
            "type": "uint256"
          }
        ],
        "internalType": "struct MessagingFee",
        "name": "msgFee",
        "type": "tuple"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
];


const OFT_ADDRESS = "0x0CEce6f83ffA618D248Dd8753e19d13DF7ed156b";
const RPC_URL = "https://rpc.ankr.com/eth_sepolia";



const main = async () => {

  const web3 = new Web3(RPC_URL);

  const GAS_LIMIT = 1000000; // Gas limit for the executor
  const MSG_VALUE = 0; // msg.value for the lzReceive() function on destination in wei
  const _options = Options.newOptions().addExecutorLzReceiveOption(GAS_LIMIT, MSG_VALUE);

  console.log(_options.toHex());

  const sendParam = [
    40102,
    "0xb57490CDAABEDb450df33EfCdd93079A24ac5Ce5" + "000000000000000000000000",
    "10000000000",
    "0",
    _options.toHex(),
    ethers.utils.arrayify('0x'),
    ethers.utils.arrayify('0x'),
  ];

  const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
  const contract = new ethers.Contract(OFT_ADDRESS, ABI, signer);

  const result = await contract.quoteSend(sendParam, false, {
    gasLimit: 1000000
  });

  console.log(result);
}

main();