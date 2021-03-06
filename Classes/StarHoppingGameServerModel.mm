//
//  StarHoppinGameServerModel.mm
//  CoinCatch
//
//  Created by Richard Lei on 11-03-01.
//  Copyright 2011 Creative Inventory Ltd. All rights reserved.
//

#import "ServerModel.hpp"



@implementation StarHoppingGameServerModel

//////////////////////////////////
//								//
//		Message dispatch		//
//								//
//////////////////////////////////

/*  MODE */

- (void) dispatchGameModeMessage
{
	GameModeMessage modeMsg;
	
	modeMsg.messageType = GameModeMessageType;
	modeMsg.gameMode = GameModeStarHop;
	
	[host handleGameModeMessage:modeMsg];
}

/* OBJECTS */




//////////////////////////
//						//
//		   Update		//
//						//
//////////////////////////

- (void) callObjectFactory
{
	int objectReceived = [myObjectFactory objectToSpawn];
	if (objectReceived != NullItemID) {
		ObjectModel* newObject = [myObjectFactory spawnObject:objectReceived];
		
		objectContainer.push_back(*newObject);
		
		[self dispatchObjectSpawnMessage:&objectContainer.back()];
		
		delete newObject;
	}
}



- (void) extendedUpdateServer:(ccTime)delta
{
	if (gameState == GameStateRunning) {
		
		/*************
		 SERVER UPDATE
		 *************/
		
		
		// Check for item spawn
		[self callObjectFactory];
		
		// update AI
		if (serverMode == ServerModeOffline) {
			[brain feedSelf:&characterContainer[brain.targetSelf] feedEnemy:&characterContainer[brain.targetEnemy] numberOfPlayers:numberOfPlayers feedItems:&itemContainer feedTime:delta motionHandler:physicsEngine];
		}
		
		
		// Update player positions
		for (int playerCount = 0; playerCount < numberOfPlayers; ++playerCount) {
			[physicsEngine moveCharacter:delta whatPlayer:characterContainer + playerCount];
		}
		
		// update Object positions
		[physicsEngine moveObjects:delta objects:&objectContainer];
		
		// Check character to character collision
		for (int playerCount = 0; playerCount < numberOfPlayers; ++playerCount) {
			for (int opponentCount = playerCount + 1; opponentCount < numberOfPlayers; ++opponentCount) {
				[physicsEngine checkPlayerToPlayerCollision:delta playerOne:characterContainer + playerCount playerTwo:characterContainer + opponentCount items:&(itemContainer)];
			}
		}
		
		// Check character ground collision
		for (int playerCount = 0; playerCount < numberOfPlayers; ++playerCount) {
			[physicsEngine checkPlayerGroundCollision:characterContainer + playerCount];
		}
		
		
		
		
		// Check character to Object collision
		for (int playerCount = 0; playerCount < numberOfPlayers; playerCount++) {
			[physicsEngine checkObjectCollision:characterContainer + playerCount objects:&objectContainer];
		}
		
		/***************
		 SERVER DISPATCH
		 ***************/
		
		// Update character positions on device
		for (int playerCount = 0; playerCount < numberOfPlayers; ++playerCount) {
			[self dispatchCharacterPositionVelocityMessage:characterContainer + playerCount];
		}
	}

}

//////////////////////////
//						//
//		   Setup		//
//						//
//////////////////////////

- (void) setupGameMode
{
	[self dispatchGameModeMessage];
}

- (void) setupPhysicsEngine
{
	CCLOG(@"SERVER: Setting up physics engine...");
	
	physicsEngine = [ServerPhysicsEngine createEngineWithServer:self modeOfGame:GameModeStarHop];
	
	float gameConstant = _GAME_CONSTANT;
	// Lower gravity, -1000.0*gameconstant is default
	physicsEngine.gravityAcceleration = -600.0*gameConstant;
	physicsEngine.groundElasticity = 700.0*gameConstant;
	physicsEngine.groundPlaneElevation = 20*gameConstant;
	
	[physicsEngine retain];
}


- (void) setupBigStarFactory
{
	myObjectFactory = [[BigStarFactory alloc] init];
	[myObjectFactory retain];

}


- (void) setupSpawnLocations
{
	CCLOG(@"SERVER: Setting up character spawn locations...");
	
	CGSize screenSize = [GameOptions screenSize];
	
	charSpawnLocations[Player1ID] = CGPointMake(screenSize.width*3/2, screenSize.height*2);
	charSpawnLocations[Player2ID] = CGPointMake(screenSize.width*1/2, screenSize.height*2);
}



- (void) setupAI
{
	// Create a thinking AI
	if (serverMode == ServerModeOffline) {
		CCLOG(@"SERVER: Setting up AI...");
		CGSize screenSize = [[CCDirector sharedDirector] winSize];
		
		brain = [StarHoppingGameAI createBrain];
		
		int selfCount;
		
		for (int playerCount = 0; playerCount < numberOfPlayers; ++playerCount) {
			if (playerList[playerCount][0] == AIControlled) {
				brain.targetSelf = playerCount;
				selfCount = playerCount;
				CCLOG(@"SERVER: AI SELF TARGET: %d.", brain.targetSelf);
			}
		}
		
		for (int playerCount = 0; playerCount < numberOfPlayers; ++playerCount) {
			if (playerCount != selfCount) {
				brain.targetEnemy = playerCount;
				CCLOG(@"SERVER: AI ENEMY TARGET: %d.", brain.targetEnemy);
			}
		}
		
		brain.min_X = 0;
		brain.max_X = screenSize.width;
		brain.min_Y = physicsEngine.groundPlaneElevation;
		brain.max_Y = screenSize.height*1.5;
		brain.gravityAcceleration = physicsEngine.gravityAcceleration;
		brain.groundElasticity = physicsEngine.groundElasticity;
		
		[brain retain];
	}
	
	
}

	
- (void) extendedSetup
{
	[self setupPhysicsEngine];
	[self setupBigStarFactory];
	[self setupAI];

}
	
- (void) dealloc
{
	objectContainer.clear();
	[physicsEngine release];
	[brain release];
	[super dealloc];
}



@end
