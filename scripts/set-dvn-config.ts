// Using ethers v5
import { ethers } from "ethers";
import "dotenv/config";

const ENDPOINT_ABI = [
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_oapp",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_lib",
        "type": "address"
      },
      {
        "components": [
          {
            "internalType": "uint32",
            "name": "eid",
            "type": "uint32"
          },
          {
            "internalType": "uint32",
            "name": "configType",
            "type": "uint32"
          },
          {
            "internalType": "bytes",
            "name": "config",
            "type": "bytes"
          }
        ],
        "internalType": "struct SetConfigParam[]",
        "name": "_params",
        "type": "tuple[]"
      }
    ],
    "name": "setConfig",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

const confirmations = 6; // Arbitrary; Varies per remote chain
const optionalDVNThreshold = 1;
const requiredDVNs = ['0xfEE967C2031364Dd6df206D10dfe5F5759b5bE0A'];
const optionalDVNs: any[] = ['0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193'];
const requiredDVNCount = requiredDVNs.length;
const optionalDVNCount = optionalDVNs.length;

// Configuration type
const configTypeUln = 2; // As defined for CONFIG_TYPE_ULN

const REMOTE_CHAIN_ENDPOINT_ID = 40102;
const ENDPOINT_ADDRESS = "0x6EDCE65403992e310A62460808c4b910D972f10f";
const MSG_LIBRARY_ADRESS = "0xcc1ae8cf5d3904cef3360a9532b477529b177cce";
const RPC_URL = "https://rpc.ankr.com/eth_sepolia";
const OAPP_ADDRESS = "0x0CEce6f83ffA618D248Dd8753e19d13DF7ed156b";



const main = async () => {
  const ulnConfigStructType = 
    'tuple(uint64 confirmations, uint8 requiredDVNCount, uint8 optionalDVNCount,' +
    ' uint8 optionalDVNThreshold, address[] requiredDVNs, address[] optionalDVNs)';

  console.log(
    ethers.utils.defaultAbiCoder.decode(
      ["tuple(uint64, uint8, uint8, uint8 , address[], address[])"], 
      "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fee967c2031364dd6df206d10dfe5f5759b5be0a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000008eebf8b423b73bfca51a1db4b7354aa0bfca9193"
    )
  );

  // const ulnConfigData = {
  //   confirmations,
  //   requiredDVNCount,
  //   optionalDVNCount,
  //   optionalDVNThreshold,
  //   requiredDVNs,
  //   optionalDVNs,
  // };
  // const ulnConfigEncoded = ethers.utils.defaultAbiCoder.encode(
  //   [ulnConfigStructType],
  //   [ulnConfigData],
  // );

  // const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
  // const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
  // const endpointContract = new ethers.Contract(ENDPOINT_ADDRESS, ENDPOINT_ABI, signer);

  // const setConfigParamUln = {
  //   eid: REMOTE_CHAIN_ENDPOINT_ID, // Replace with your remote chain's endpoint ID (source or destination)
  //   configType: configTypeUln,
  //   config: ulnConfigEncoded,
  // };

  // const tx = await endpointContract.setConfig(OAPP_ADDRESS, MSG_LIBRARY_ADRESS, [
  //   setConfigParamUln,
  // ], {
  //   gasLimit: 1000000
  // });
  
  // const result = await tx.wait();
  // console.log(result);
}

main();