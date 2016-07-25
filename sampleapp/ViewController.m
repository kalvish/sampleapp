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

@end

@implementation ViewController

@synthesize dataChannel = _dataChannel;
@synthesize factory = _factory;
@synthesize isInitiator = _isInitiator;
@synthesize peerConnection = _peerConnection;


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _factory = [[RTCPeerConnectionFactory alloc] init];
    
    // Do any additional setup after loading the view, typically from a nib.
    [SIOSocket socketWithHost: @"http://54.186.253.62:8080" response: ^(SIOSocket *socket)
     {
         self.socketSIO = socket;
         
         [self.socketSIO on: @"created" callback: ^(SIOParameterArray *args)
          {
              NSLog(@"room created");
              _isInitiator = true;
              [self createPeerConnection];
          }];
         
         [self.socketSIO on: @"joined" callback: ^(SIOParameterArray *args)
          {
              NSLog(@"room joined");
              _isInitiator = false;
          }];
         
         [self.socketSIO on: @"presence" callback: ^(SIOParameterArray *args)
          {
              NSLog(@"room presence");
              _isInitiator = false;
          }];
         
         [self.socketSIO on: @"ready" callback: ^(SIOParameterArray *args)
          {
              NSLog(@"room ready");
              [self createPeerConnection];
          }];
         
         [self.socketSIO on: @"message" callback: ^(SIOParameterArray *args)
          {
              NSDictionary *temp = [args firstObject];
              NSString *type = temp[@"type"];
              if(type){
                  if([type isEqualToString:@"offer"]){
                      RTCSessionDescription *description =
                      [RTCSessionDescription descriptionFromJSONDictionary:temp];
                      if(_peerConnection){
                          [_peerConnection setRemoteDescriptionWithDelegate:self
                                                         sessionDescription:description];
                      }
                  }else if ([type isEqualToString:@"answer"]){
                      RTCSessionDescription *description =
                      [RTCSessionDescription descriptionFromJSONDictionary:temp];
                      if(_peerConnection){
                          [_peerConnection setRemoteDescriptionWithDelegate:self
                                                         sessionDescription:description];
                          
                      }
                  }
              }
              NSDictionary *candidateDict = temp[@"candidate"];
              if(candidateDict){
                    RTCICECandidate *candidate =
                      [RTCICECandidate candidateFromJSONDictionary:candidateDict];
                  if(_peerConnection){
                      [_peerConnection addICECandidate:candidate];
                  }
                  
                  
              }
             
              NSLog(@"room message");
              
          }];

         
         [self.socketSIO emit: @"createroom" args: @[
                                                         @"testroom1"
                                                         ]];
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

    
    if (_isInitiator) {
        
        //Create data channel
        RTCDataChannelInit *initData = [[RTCDataChannelInit alloc] init];
        _dataChannel = [_peerConnection createDataChannelWithLabel:@"BoardPACDataChannel" config:initData];
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
            
            NSError *error;
            int tempInt = 345;
            NSDictionary *messageDict = @{@"message": [NSString stringWithFormat:@"%d",tempInt]};
            NSData *messageData = [NSJSONSerialization dataWithJSONObject:messageDict options:0 error:&error];
            if (!error)
            {
                RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:messageData isBinary:NO];
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
    NSData *temp = buffer.data;
    NSString *myString = [[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding];
    NSLog(@"%@", myString);
    
    NSError *error;
    int tempInt = 345;
    NSDictionary *messageDict = @{@"message": [NSString stringWithFormat:@"%d",tempInt]};
    NSData *messageData = [NSJSONSerialization dataWithJSONObject:messageDict options:0 error:&error];
    if (!error)
    {
        RTCDataBuffer *data = [[RTCDataBuffer alloc] initWithData:messageData isBinary:NO];
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
    [self.socketSIO emit: @"message" args: @[tempString]];
    //[self.socketSIO emit: @"message" args: @[@"gotICECandidate"]];
    //[self.socketSIO emit: @"message" args: @[
         //                                           @"testroom1"
         //                                           ]];
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
       // NSString *tempString = [description description];
        [self.socketSIO emit: @"message" args: @[data]];
        //[self.socketSIO emit: @"message" args: @[@"didCreateSessionDescription"]];
        //[self.socketSIO emit: @"message" args: @[
        //                                         @"testroom1"
         //                                        ]];
//        ARDSessionDescriptionMessage *message =
//        [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
//        [self sendSignalingMessage:message];
        
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

@end
