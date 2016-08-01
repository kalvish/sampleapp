//
//  ViewController.m
//  sampleapp
//
//  Created by ganuka on 7/20/16.
//  Copyright © 2016 vishwan. All rights reserved.
//

#import "ViewController.h"

#import "SIOSocket.h"

#import "RTCDataChannel.h"
#import "RTCICECandidate+JSON.h"
#import "RTCMediaConstraints.h"
#import "RTCPair.h"
#import "RTCPeerConnection.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCSessionDescription+JSON.h"
#import "RTCSessionDescriptionDelegate.h"

@interface ViewController () <RTCPeerConnectionDelegate,RTCDataChannelDelegate,RTCSessionDescriptionDelegate>

@property(nonatomic, strong) RTCDataChannel *dataChannel;
@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, assign) BOOL isInitiator;
@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property SIOSocket *socketSIO;

@property NSString *roomJoined;
@property NSString *userClientId;

@property(nonatomic, assign) BOOL isCommpacClientCreatedPeerConnection;
@property(nonatomic, assign) BOOL isCommpacRoomCreatedOrJoined;


@property(nonatomic, assign) BOOL isPresenter;

@property NSMutableData *rxData;
@end

@implementation ViewController

@synthesize imageReceived;

@synthesize rxData;
int rxDataCount = 0;
int intMediaLength = 0;

@synthesize dataChannel = _dataChannel;
@synthesize factory = _factory;
@synthesize isInitiator = _isInitiator;
@synthesize peerConnection = _peerConnection;

@synthesize roomJoined;
@synthesize userClientId;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _factory = [[RTCPeerConnectionFactory alloc] init];
    
    // Do any additional setup after loading the view, typically from a nib.
    [SIOSocket socketWithHost: @"http://54.186.253.62:8080" response: ^(SIOSocket *socket)
     {
         self.socketSIO = socket;
         
//         [self.socketSIO on: @"created" callback: ^(SIOParameterArray *args)
//          {
//              NSLog(@"room created");
//              _isInitiator = true;
//              [self createPeerConnection];
//          }];
//         
//         [self.socketSIO on: @"joined" callback: ^(SIOParameterArray *args)
//          {
//              NSLog(@"room joined");
//              _isInitiator = false;
//          }];
         
         [self.socketSIO on: @"commpac client created peer connection" callback: ^(SIOParameterArray *args)
          {
              //_isCommpacRoomCreatedOrJoined is added not to run this twice for other users in the system (for their broadcasts).
              if(!_isCommpacClientCreatedPeerConnection){
                  _isCommpacClientCreatedPeerConnection = true;
                  
                  int a = 0;
                  NSLog(@"commpac client created peer connection");
                  
                  _isInitiator = true;
                  [self createPeerConnection];
              }
             
          }];
         
         [self.socketSIO on: @"commpac room created" callback: ^(SIOParameterArray *args)
          {
              //_isCommpacRoomCreatedOrJoined is added not to run this twice for other users in the system (for their broadcasts).
              if(!_isCommpacRoomCreatedOrJoined){
                  _isCommpacRoomCreatedOrJoined = true;
                  
                  NSDictionary *temp = [args firstObject];
                  NSString *room = temp[@"room"];
                  if(room){
                      self.roomJoined = room;
                  }
                  NSString *clientid = temp[@"clientid"];
                  if(clientid){
                      self.userClientId = clientid;
                  }
                  NSLog(@"room created %@, %@",room,clientid);
                  _isInitiator = true;
                  //[self createPeerConnection];
                  
                  [self.socketSIO emit: @"commpac server create peer connection" args: @[@{@"room":room, @"clientid":clientid}]];
              }
             
          }];
         
         [self.socketSIO on: @"commpac room joined" callback: ^(SIOParameterArray *args)
          {
              //_isCommpacRoomCreatedOrJoined is added not to run this twice for other users in the system (for their broadcasts).
              if(!_isCommpacRoomCreatedOrJoined){
                  _isCommpacRoomCreatedOrJoined = true;
                  
                  NSDictionary *temp = [args firstObject];
                  NSString *room = temp[@"room"];
                  if(room){
                      self.roomJoined = room;
                  }
                  NSString *clientid = temp[@"clientid"];
                  if(clientid){
                      self.userClientId = clientid;
                  }
                  NSLog(@"room created %@, %@",room,clientid);
                  //is initiator set to true for server based star topology conferencing
                  _isInitiator = true;
                  
                  [self.socketSIO emit: @"commpac server create peer connection" args: @[@{@"room":room, @"clientid":clientid}]];
              }
              
          }];
//         
//         [self.socketSIO on: @"presence" callback: ^(SIOParameterArray *args)
//          {
//              NSLog(@"room presence");
//              _isInitiator = false;
//          }];
//         
//         [self.socketSIO on: @"ready" callback: ^(SIOParameterArray *args)
//          {
//              NSLog(@"room ready");
//              [self createPeerConnection];
//          }];
         
         
         //[self.socketSIO on: @"message" callback: ^(SIOParameterArray *args)
         [self.socketSIO on: @"commpac client message" callback: ^(SIOParameterArray *args)
          {
              NSDictionary *temp = [args firstObject];
              NSString *roomRx = temp[@"room"];
              NSString *clientidRx = temp[@"clientid"];
              if([roomRx isEqualToString:self.roomJoined] && [clientidRx isEqualToString:self.userClientId]){
                  NSDictionary *contentDict = temp[@"content"];
                  NSString *type = contentDict[@"type"];
                  if(type){
                      if([type isEqualToString:@"offer"]){
                          RTCSessionDescription *description =
                          [RTCSessionDescription descriptionFromJSONDictionary:contentDict];
                          if(_peerConnection){
                              [_peerConnection setRemoteDescriptionWithDelegate:self
                                                             sessionDescription:description];
                          }
                      }else if ([type isEqualToString:@"answer"]){
                          RTCSessionDescription *description =
                          [RTCSessionDescription descriptionFromJSONDictionary:contentDict];
                          if(_peerConnection){
                              [_peerConnection setRemoteDescriptionWithDelegate:self
                                                             sessionDescription:description];
                              
                          }
                      }
                  }
                  NSDictionary *candidateDict = contentDict[@"candidate"];
                  if(candidateDict){
                      RTCICECandidate *candidate =
                      [RTCICECandidate candidateFromJSONDictionary:candidateDict];
                      if(_peerConnection){
                          [_peerConnection addICECandidate:candidate];
                      }
                      
                      
                  }
                  
                  NSLog(@"room message");
              }
            
              
          }];

         
//         [self.socketSIO emit: @"createroom" args: @[
//                                                         @"testroom1"
//                                                         ]];
//         
//         [self.socketSIO emit: @"commpac server room create or join" args: @[
//                                                     @"testroom1"
//                                                     ]];
         
//         [self.socketSIO emit: @"create or join" args: @[
//                                                         @"testroom1"
//                                                         ]];
//         [self.socketSIO emit: @"presence" args: @[
//                                                         @"presence"
//                                                         ]];
     }];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) createPeerConnection {
    
    // Create peer connection.
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    _peerConnection = [_factory peerConnectionWithICEServers:nil /*_iceServers*/
                                                 constraints:constraints
                                                    delegate:self];
    //_peerConnection = [_factory peerConnectionWithConfiguration:nil constraints:nil delegate:self ];

    
    if (_isInitiator) {
        
        //Create data channel
        RTCDataChannelInit *initData = [[RTCDataChannelInit alloc] init];
        NSString *channelName = [NSString stringWithFormat:@"%@%@%@", self.roomJoined, @"commpac", self.userClientId];
        _dataChannel = [_peerConnection createDataChannelWithLabel:channelName config:initData];
        //_dataChannel = [_peerConnection createDataChannelWithLabel:@"BoardPACDataChannel" config:initData];
        _dataChannel.delegate = self;
        
        [_peerConnection createOfferWithDelegate:self
                                     constraints:[self defaultOfferConstraints]];
    } else {
        //[self waitForAnswer];
        
        
    }
}

#pragma mark Helper methods

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"false"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"internalSctpDataChannels" value:@"true"],
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]
                                     ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}

#pragma mark RTCDataChannelDelegate methods
// Called when the data channel state has changed.
- (void)channelDidChangeState:(RTCDataChannel*)channel {
    switch (channel.state)
    {
        case kRTCDataChannelStateConnecting:
            NSLog(@"Direct connection CONNECTING");
            break;
            
        case kRTCDataChannelStateOpen:
        {
            NSLog(@"Direct connection OPEN");
            //[call directConnectionDidOpen:self];
            dispatch_async(dispatch_get_main_queue(), ^{
                //[self.delegate onOpen:self];
            });
            
//            NSError *error;
//            int tempInt = 345;
//            NSDictionary *messageDict = @{@"message": [NSString stringWithFormat:@"%d",tempInt]};
//            NSData *messageData = [NSJSONSerialization dataWithJSONObject:messageDict options:0 error:&error];
//            if (!error)
//            {
//                RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:messageData isBinary:NO];
//                //RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:imagedata isBinary:NO];
//                if ([_dataChannel sendData:data])
//                {
//                    //successHandler();
//                    int a = 0;
//                }
//                else
//                {
//                    //errorHandler(@"Message failed to send");
//                }
//            }
//            else
//            {
//                //errorHandler(@"Unable to encode message to JSON");
//            }
        }
            break;
            
        case kRTCDataChannelStateClosing:
            NSLog(@"Direct connection CLOSING");
            break;
            
        case kRTCDataChannelStateClosed:
        {
            NSLog(@"Direct connection CLOSED");
            _dataChannel = nil;
            //[call directConnectionDidClose:self];
            dispatch_async(dispatch_get_main_queue(), ^{
                //[self.delegate onClose:self];
            });
        }
            break;
    }

}

// Called when a data buffer was successfully received.
- (void)channel:(RTCDataChannel*)channel
didReceiveMessageWithBuffer:(RTCDataBuffer*)buffer {
//    NSData *temp = buffer.data;
//    NSString *myString = [[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding];
//    NSLog(@"%@", myString);
    
    if(!_isPresenter){
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData *temp = buffer.data;
            
            NSString* str = [[NSString alloc] initWithData:temp
                                                  encoding:NSUTF8StringEncoding];
            
            if (str && [str length] > 0){
                NSLog(@"Contains string");
                
                NSError *error;
                id jsonResult = [NSJSONSerialization JSONObjectWithData:temp options:0 error:&error];
                if (jsonResult && ([jsonResult isKindOfClass:[NSDictionary class]]))
                {
                    NSDictionary *dict = (NSDictionary*)jsonResult;
                    NSString *messageText = [dict objectForKey:@"message"];
                    
                    if (messageText)
                    {
                        intMediaLength = [messageText intValue];
                        rxData = nil;
                        rxDataCount = 0;
                        NSLog(@"Direct Message received: [%@], int value is %d", messageText, intMediaLength);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            //[self.delegate onMessage:messageText sender:self];
                        });
                    }
                }else{
                    NSLog(@"Does't contains string");
                    
                    //                if(rxData==nil){
                    //                    rxData = [[NSMutableData alloc] init];
                    //                }
                    //                NSData *tempChunk = buffer.data;
                    //                [rxData appendData:tempChunk];
                    //                rxDataCount+=tempChunk.length;
                    //
                    //                if(rxDataCount==intMediaLength){
                    //                    UIImage *imageRx= [UIImage imageWithData:rxData];
                    //                    [imageReceived setImage:imageRx];
                    //                }
                }
            }else{
                NSLog(@"Does't contains string");
                
                if(rxData==nil){
                    rxData = [[NSMutableData alloc] init];
                }
                
                [rxData appendData:temp];
                rxDataCount+=temp.length;
                
                if(rxDataCount==intMediaLength){
                    UIImage *imageRx= [UIImage imageWithData:rxData];
                    [imageReceived setImage:imageRx];
                }
            }
            
        });
    }

    
//    NSError *error;
//    int tempInt = 345;
//    NSDictionary *messageDict = @{@"message": [NSString stringWithFormat:@"%d",tempInt]};
//    NSData *messageData = [NSJSONSerialization dataWithJSONObject:messageDict options:0 error:&error];
//    if (!error)
//    {
//        RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:messageData isBinary:NO];
//        //RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:imagedata isBinary:NO];
//        if ([_dataChannel sendData:data])
//        {
//            //successHandler();
//            int a = 0;
//        }
//        else
//        {
//            //errorHandler(@"Message failed to send");
//        }
//    }
//    else
//    {
//        //errorHandler(@"Unable to encode message to JSON");
//    }
}

#pragma mark Data Channel methods
- (BOOL)isActive
{
    return (_dataChannel && (_dataChannel.state == kRTCDataChannelStateOpen));
}

#pragma mark RTCPeerConnectionDelegate methods
// Triggered when the SignalingState changed.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged {
    NSLog(@"Signaling state changed: %d", stateChanged);
}

// Triggered when media is received on a new stream from remote peer.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream {
    NSLog(@"addedStream");
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {
    NSLog(@"removedStream");
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState {
    NSLog(@"ICE state changed: %d", newState);
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState {
    NSLog(@"ICE gathering state changed: %d", newState);
}

// New Ice candidate have been found.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
    RTCICECandidate *tempCandidate = candidate;
    NSDictionary *tempString = [tempCandidate getJSONDataCandidate];
    //[self.socketSIO emit: @"message" args: @[tempString]];
    
    if(self.roomJoined){
        [self.socketSIO emit: @"commpac server message" args: @[@{@"room":self.roomJoined , @"clientid":self.userClientId , @"content": tempString , @"from": @"client"}]];
    }
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)newDataChannel {
    if (_dataChannel)
    {
        // Replacing the previous connection, so disable delegate messages from the old instance
        _dataChannel.delegate = nil;
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            //Respoke
            // This callback will not be called in this test. It is only triggered when adding a directConnection to an existing call, which is currently not supported.
            //  [self.delegate onStart:self];
        });
    }
    
    _dataChannel = newDataChannel;
    _dataChannel.delegate = self;
}

#pragma mark RTCSessionDescriptionDelegate methods
// Called when creating a session.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to create session description. Error: %@", error);
           // [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to create session description.",
                                       };
//            NSError *sdpError =
//            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
//                                       code:kARDAppClientErrorCreateSDP
//                                   userInfo:userInfo];
           // [_delegate appClient:self didError:sdpError];
            return;
        }
        [_peerConnection setLocalDescriptionWithDelegate:self
                                      sessionDescription:sdp];
        RTCSessionDescription *description = sdp;
        NSDictionary *data = [description getJSONDataSDP];

        //[self.socketSIO emit: @"message" args: @[data]];
        //var messageToSend = {room:myRoom,clientid:myCliendId,content:message,from:'client'};
        if(self.roomJoined && self.userClientId){
            [self.socketSIO emit: @"commpac server message" args: @[@{@"room":self.roomJoined , @"clientid":self.userClientId , @"content": data , @"from": @"client"}]];
        }
        
    });
}

// Called when setting a local or remote description.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to set session description. Error: %@", error);
            //[self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
//            NSError *sdpError =
//            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
//                                       code:kARDAppClientErrorSetSDP
//                                   userInfo:userInfo];
//            [_delegate appClient:self didError:sdpError];
            return;
        }
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.

        if (!_isInitiator && !_peerConnection.localDescription) {
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            [_peerConnection createAnswerWithDelegate:self
                                          constraints:constraints];
            
        }
    });
}

#pragma mark ui methods
-(void)onclickstart:(id)sender {
    NSString * roomText = self.roomText.text;
    if(roomText){
        [self.socketSIO emit: @"commpac server room create or join" args: @[
                                                                            roomText
                                                                            ]];
    }
}

-(void)onSendMessageToPeer:(id)sender {
    _isPresenter = true;
    // start the loop
    [self incrementCounter:[NSNumber numberWithInt:0]];
}

-(void) incrementCounter:(NSNumber *)i {

        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
            UIGraphicsBeginImageContextWithOptions(self.view.window.bounds.size, NO, [UIScreen mainScreen].scale);
        else
            UIGraphicsBeginImageContext(self.view.window.bounds.size);
        
        [self.view.window.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        //[imageReceived setImage:image];
        [self sendMessage:image];
        
        
    
    // [myLabel setText:[NSString stringWithFormat:@"%d", [i intValue]]]; // show the result!
    [self performSelector:@selector(incrementCounter:) withObject:[NSNumber numberWithInt:i.intValue+1] afterDelay:0.2];
}

- (void)sendMessage:(UIImage*)imageToSend {
    if ([self isActive])
    {
        //NSData *imagedata = UIImagePNGRepresentation(imageToSend);
        NSData *imagedata = UIImageJPEGRepresentation(imageToSend, 0.3f);
        NSUInteger imageDataLength = [imagedata length];
        NSLog(@"image size : %d",imageDataLength);
        //-----------
        
        
        NSError *error;
        int tempInt = imageDataLength;
        NSDictionary *messageDict = @{@"message": [NSString stringWithFormat:@"%d",tempInt]};
        NSData *messageData = [NSJSONSerialization dataWithJSONObject:messageDict options:0 error:&error];
        
       
        
        if (!error)
        {
            RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:messageData isBinary:YES];
            //RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:imagedata isBinary:NO];
            if ([_dataChannel sendData:data])
            {
                //successHandler();
                int a = 0;
            }
            else
            {
                //errorHandler(@"Message failed to send");
            }
        }
        else
        {
            //errorHandler(@"Unable to encode message to JSON");
        }
        
        
        // NSDictionary *messageDict = @{@"message": message};
        // NSData *messageData = [NSJSONSerialization dataWithJSONObject:messageDict options:0 error:&error];
        
        NSUInteger chunkSize = 12 * 1024;
        NSUInteger offset = 0;
        do {
            NSUInteger thisChunkSize = imageDataLength - offset > chunkSize ? chunkSize : imageDataLength - offset;
            NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[imagedata bytes] + offset
                                                 length:thisChunkSize
                                           freeWhenDone:NO];
            NSLog(@"chunk length : %lu",(unsigned long)chunk.length);
          
            RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:[NSData dataWithData:chunk] isBinary:YES];
            if ([_dataChannel sendData:data])
            {
                //successHandler();
                int a = 0;
            }
            else
            {
                //errorHandler(@"Message failed to send");
            }
            //[marrFileData addObject:[NSData dataWithData:chunk]];
            offset += thisChunkSize;
        } while (offset < imageDataLength);
    }else
    {
        //errorHandler(@"dataChannel not in an open state.");
    }
}
@end
