import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:walletconnect_flutter/util.dart';
import 'package:web3dart/credentials.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class WalletConnectTestPage extends StatefulWidget {
  const WalletConnectTestPage({Key? key}) : super(key: key);

  @override
  _WalletConnectTestPageState createState() => _WalletConnectTestPageState();
}

class _WalletConnectTestPageState extends State<WalletConnectTestPage> {

  // late WalletConnectJsonRpc _jsonRpc;
  final stateMessage = 'none'.obs;
  final balance = ''.obs;
  String adminAddress = '0x30a84B82ea0a65EADffBc70968d76A26f725d13c';
  String userAddress = '0x19bab99cd651de243945fab92a7fa0ec0faea061';
  String key = '201627e4b16cd09ea951a95b1a4cd302';
  String bridge = 'https://bridge.walletconnect.org';
  String version = '1';
  String topic = '';
  String? address;
  int chainId = 4; // rinkby testnet
  // String rpcUrl = 'https://data-seed-prebsc-1-s1.binance.org:8545/'; // bsc testnet
  String rpcUrl = 'https://rpc.ankr.com/eth_rinkeby'; // bsc testnet
  String testContractAddress = '0xcbcd51b2ae1beaa8c159ff79e9ad383ac80f7fc7';

  Web3Client? _client;
  Web3Client get client {
    if(_client == null){
      debugLog('create web3 client');
      _client = Web3Client(rpcUrl, Client());
    }
    return _client!;
  }

  // ERC721? _contract;
  // ERC721 get contract {
  //   if(_contract == null){
  //     debugLog('create contract instance');
  //     _contract = ERC721(
  //       address: EthereumAddress.fromHex(testContractAddress), // astarz dev nft 1391
  //       client: client,
  //     );
  //   }

  // return _contract!;
  // }

  // Create a connector
  final connector = WalletConnect(
    bridge: 'https://bridge.walletconnect.org',
    clientMeta: PeerMeta(
      name: 'A-Starz',
      description: 'This is a NFT market place with membership media contents.',
      url: 'https://a-starz.co.kr',
      icons: [
        // 'https://gblobscdn.gitbook.com/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media'
      ],
    ),
  );

// Subscribe to events
  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    connector.on('connect', (session) {
      stateMessage.value = 'connect $session';
      debugLog('connect', session);
    });
    connector.on('session_update', (payload){
      stateMessage.value = 'session_update $payload';
      debugLog('session_update', payload);
    });
    connector.on('disconnect', (session) {
      stateMessage.value = 'disconnect $session';
      debugLog('disconnect', session);
    });
  }

  personalSignTest() async {
    if(address != null){
      String message = 'test message';
      String encodedMessage = toHexString(message);
      debugLog('personalSignTest $message $encodedMessage $address');
      var isLaunched = await launch(Uri.encodeFull('wc:$topic@$version?bridge=$bridge&key=$key'));
      if(isLaunched){
        var res = await connector.sendCustomRequest(method: 'personal_sign', params: [message, address!.toLowerCase()]);
        debugLog('personal_sign signature : $res');
        String signature = res;

        String decoded = EthSigUtil.recoverPersonalSignature(
          signature: signature,
          message: toHash(message),
        );

        debugLog('decoded $decoded');
        bool isSignMatch = decoded.toLowerCase() == address!.toLowerCase();
        if(isSignMatch){
          stateMessage.value = 'personal match ${{
            'address': address!,
            'signature': signature,
            'message': message,
            'decoded':  decoded,
          }}';
        }
        else {
          stateMessage.value = 'personal sign mismatch ${{
            'address': address!,
            'signature': signature,
            'message': message,
            'decoded':  decoded,
          }}';
        }
      }
      else {
        errorLog('personal sign fail : wallet not launched');
      }

    }
    else {
      errorLog('address is null');
    }
  }

  contractNameTest() async {
    // debugLog('get contract name');
    // var name = await contract.name();
    // debugLog('get contract name : $name');
  }

  getTokenUri() async {
    // debugLog('get contract tokenUri');
    // var tokenUri = await contract.tokenURI(BigInt.one);
    // debugLog('get contract tokenUri : $tokenUri');
  }

  getOwner() async {
    // debugLog('get contract getOwner');
    // var owner = await contract.ownerOf(BigInt.one);
    // debugLog('get contract getOwner : $owner');
  }


  Uint8List toHash(String message){
    final messageHex = utf8.encode(message);
    final messagePrefix = '\u0019Ethereum Signed Message:\n';
    final prefix = messagePrefix + messageHex.length.toString();
    final prefixHex = utf8.encode(prefix);
    final concatHex = Uint8List.fromList(prefixHex + messageHex);
    return keccak256(concatHex);
  }

  String toHexString(String message){
    var encoded = utf8.encode(message);
    var toString = encoded.map((e) => e.toRadixString(16)).join();
    return '0x$toString';
  }

  @override
  void dispose() {
    connector.killSession();
    connector.close();
    _client?.dispose();
    super.dispose();
  }

  requestConnect() async {
    if (connector.connected) {
      await connector.killSession();
    }
    final session = await connector.createSession(
      chainId: chainId,
      onDisplayUri: (uri){
        stateMessage.value = 'onDisplayUri $uri';
        launch(uri);
      },
    );
    stateMessage.value = 'createSession success $session';
    debugLog(session.accounts);
    address = session.accounts[0];
    if(address != null){
      getBalance(address: address!);
    }
  }

  sendNFT({
    required int tokenId,
    required String fromAddress,
    required String toAddress,
  }) async {
    try{
      var isLaunched = await launch(Uri.encodeFull('wc:$topic@$version?bridge=$bridge&key=$key'));
      if(isLaunched){
        EthereumWalletConnectProvider provider = EthereumWalletConnectProvider(connector);
        var credentials = WalletConnectEthereumCredentials(provider: provider);
        debugLog('sendNFT $fromAddress -> $toAddress $tokenId');
        // var res = await contract.safeTransferFrom(
        //   EthereumAddress.fromHex(fromAddress),
        //   EthereumAddress.fromHex(toAddress),
        //   BigInt.from(tokenId),
        //   credentials: credentials,
        //   transaction: Transaction(
        //     from: EthereumAddress.fromHex(fromAddress),
        //     to: EthereumAddress.fromHex(toAddress),
        //   ),
        // );
        // debugLog(res);
      }
      else {
        errorLog('sendNFT error : wallet not launched');
      }
    }
    catch(e, stack){
      errorLog('sendNFT error',e, stack);
    }
  }



  sendEth() async {
    try{
      var isLaunched = await launch(Uri.encodeFull('wc:$topic@$version?bridge=$bridge&key=$key'));
      if(isLaunched){
        EthereumWalletConnectProvider provider = EthereumWalletConnectProvider(connector);
        var credentials = WalletConnectEthereumCredentials(provider: provider);
        // debugLog('sendNFT $fromAddress -> $toAddress $tokenId');
        var res = await client.sendTransaction(
          credentials,
          Transaction(
            from: EthereumAddress.fromHex(address!),
            to: EthereumAddress.fromHex(address!),
            value: EtherAmount.fromUnitAndValue(EtherUnit.gwei, 10000000),
          ),
        );
        debugLog(res);
      }
      else {
        errorLog('sendNFT error : wallet not launched');
      }
    }
    catch(e, stack){
      errorLog('sendNFT error',e, stack);
    }
  }


  getBalance({
    required String address,
  }) async {
    var bal = await client.getBalance(EthereumAddress.fromHex(address));
    balance.value = (bal.getInWei / BigInt.from(pow(10.0, 18.0))).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('wallet connect test'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(()=>Text(
            'state : ${stateMessage.value}',
          )),

          Obx(()=>Text(
            'balance : ${balance.value}',
          )),
          buildButton(
            text: 'requestConnect',
            onTap: requestConnect,
          ),
          buildButton(
            text: 'personalSignTest',
            onTap: personalSignTest,
          ),
          buildButton(
            text: 'sendEth',
            onTap: sendEth,
          ),
          buildButton(
            text: 'getBalance',
            onTap: ()=>getBalance(address: address!),
          ),

          // buildButton(
          //   text: 'contractNameTest',
          //   onTap: contractNameTest,
          // ),
          // buildButton(
          //   text: 'getTokenUri',
          //   onTap: getTokenUri,
          // ),
          // buildButton(
          //   text: 'getOwner',
          //   onTap: getOwner,
          // ),

          // buildButton(
          //   text: 'getOwner',
          //   onTap: ()=>getBalance(address: address!),
          // ),
          //
          // buildButton(
          //   text: 'adminToUser',
          //   onTap: () async {
          //     await sendNFT(
          //       tokenId: 1,
          //       fromAddress: adminAddress,
          //       toAddress: userAddress,
          //     );
          //     await getOwner();
          //   },
          // ),
          //
          // buildButton(
          //   text: 'userToAdmin',
          //   onTap: () async {
          //     await sendNFT(
          //       tokenId: 1,
          //       fromAddress: userAddress,
          //       toAddress: adminAddress,
          //     );
          //     await getOwner();
          //   },
          // ),
        ],
      ),
    );
  }

  Widget buildButton({
    required String text,
    required VoidCallback onTap,
  }){
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.lightBlue,
          ),
        ),
      ),
    );
  }
}

class WalletConnectEthereumCredentials extends CustomTransactionSender {
  WalletConnectEthereumCredentials({required this.provider});

  final EthereumWalletConnectProvider provider;

  @override
  Future<EthereumAddress> extractAddress() {
    // TODO: implement extractAddress
    throw UnimplementedError();
  }

  @override
  Future<String> sendTransaction(Transaction transaction) async {
    final hash = await provider.sendTransaction(
      from: transaction.from!.hex,
      to: transaction.to?.hex,
      data: transaction.data,
      gas: transaction.maxGas,
      gasPrice: transaction.gasPrice?.getInWei,
      value: transaction.value?.getInWei,
      nonce: transaction.nonce,
    );

    return hash;
  }

  @override
  Future<MsgSignature> signToSignature(Uint8List payload,
      {int? chainId, bool isEIP1559 = false}) {
    // TODO: implement signToSignature
    throw UnimplementedError();
  }
}