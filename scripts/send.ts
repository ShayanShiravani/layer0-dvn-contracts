// Using ethers v5
import { BigNumber, ethers } from "ethers";
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
        "name": "_fee",
        "type": "tuple"
      },
      {
        "internalType": "address",
        "name": "_refundAddress",
        "type": "address"
      }
    ],
    "name": "send",
    "outputs": [
      {
        "components": [
          {
            "internalType": "bytes32",
            "name": "guid",
            "type": "bytes32"
          },
          {
            "internalType": "uint64",
            "name": "nonce",
            "type": "uint64"
          },
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
            "name": "fee",
            "type": "tuple"
          }
        ],
        "internalType": "struct MessagingReceipt",
        "name": "msgReceipt",
        "type": "tuple"
      },
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "amountSentLD",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "amountReceivedLD",
            "type": "uint256"
          }
        ],
        "internalType": "struct OFTReceipt",
        "name": "oftReceipt",
        "type": "tuple"
      }
    ],
    "stateMutability": "payable",
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
    "1000000000000000000",
    "0",
    _options.toHex(),
    ethers.utils.arrayify('0x'),
    ethers.utils.arrayify('0x'),
  ];

  const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
  const contract = new ethers.Contract(OFT_ADDRESS, ABI, signer);

  const tx = await contract.send(
    sendParam, 
    ["2181497718106058","0"],
    "0xb57490CDAABEDb450df33EfCdd93079A24ac5Ce5",
    {
      gasLimit: 1000000,
      value: BigNumber.from("2181497718106058")
    }
  );

  const result = await tx.wait();

  console.log(result);
}

main();