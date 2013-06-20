//***************************************************
// HTML Pong v0.1
// Author: edokoa
// Website: www.edokoa.com
// Contact: hello@edokoa.com
//
// This code is made with educational purposes and is licensed under a CREATIVE COMMONS: BY-NC-SA license.
//
// The code is provided as-is and I don't hold any responability derived from the use of this program or part of it.
//
//
//	PLAYER CONTROLS
//		Q: Player1 UP
//		A: Player1 DOWN
//		O: Player2 UP
//		K: Player2 DOWN
//
//	This is an early version and it freezes when a player goes over 9 points. To restart a match you should refresh the browser window.
//		
//***************************************************

var field = document.getElementById("playfield");
var player1 = document.getElementById("player1");
var player2 = document.getElementById("player2");
var ball = document.getElementById("ball");			
var keys = [0,0,0,0];								//array of pressed keys
var p1Display = [];									//those arrays will contain the player scores
var p2Display = [];
var p1Score = 0;
var p2Score = 0;
var scoreNumbers =									//If you look closely, this array contains sprites for the numbers (1=Pixel on, 0=Pixel off), they are hard-coded number sprites from 0 to 9 
[													//It's a 3D array where [actual number][pixel row][pixel column]
	[					//0
	[1,1,1,1],
	[1,0,0,1],
	[1,0,0,1],
	[1,0,0,1],
	[1,1,1,1]
	],
	[					//1
	[0,0,0,1],
	[0,0,0,1],
	[0,0,0,1],
	[0,0,0,1],
	[0,0,0,1]
	],
	[					//2
	[1,1,1,1],
	[0,0,0,1],
	[1,1,1,1],
	[1,0,0,0],
	[1,1,1,1]
	],
	[					//3
	[1,1,1,1],
	[0,0,0,1],
	[1,1,1,1],
	[0,0,0,1],
	[1,1,1,1]
	],
	[					//4
	[1,0,0,1],
	[1,0,0,1],
	[1,1,1,1],
	[0,0,0,1],
	[0,0,0,1]
	],
	[					//5
	[1,1,1,1],
	[1,0,0,0],
	[1,1,1,1],
	[0,0,0,1],
	[1,1,1,1]
	],
	[					//6
	[1,1,1,1],
	[1,0,0,0],
	[1,1,1,1],
	[1,0,0,1],
	[1,1,1,1]
	],
	[					//7
	[1,1,1,1],
	[0,0,0,1],
	[0,0,0,1],
	[0,0,0,1],
	[0,0,0,1]
	],
	[					//8
	[1,1,1,1],
	[1,0,0,1],
	[1,1,1,1],
	[1,0,0,1],
	[1,1,1,1]
	],
	[					//9
	[1,1,1,1],
	[1,0,0,1],
	[1,1,1,1],
	[0,0,0,1],
	[1,1,1,1]
	],
	
];



function updateScore(whichPlayer){							//this function adds points to scores and updates the numbers in the diplays
	if(whichPlayer==1) {									//right now the game freezes when a player has more than 9 points. The victory control should be inside of this function.
		currentDisplay = p1Display;
		p1Score++;
		currentScore = p1Score;
	} else {
		currentDisplay = p2Display;
		p2Score++;
		currentScore = p2Score;
	}
	
	
	
	for(i=0;i<5;i++)										//Here I'm wiping the current 2D array and substituting it with the appropiate number from the big array (in binary format as on/off pixels)
	{
		row=[];
		for(j=0;j<4;j++)
		{
			pixel=currentDisplay[i][j];
			currentPix=scoreNumbers[currentScore][i][j];
			if(currentPix){
				pixel.style.opacity=1;
			}
			else {
				pixel.style.opacity=0;
			}
		}
	}	
}


function createScores(){									//this creates the grids that will be used for displaying the scores

	for(p=1;p<=2;p++)
	{	
		pScore=document.createElement("div");
		pScore.className="score";
		if(p==1) pScore.id="p1Score";
		else pScore.id="p2Score";
		
		for(i=0;i<5;i++)									//creates the <div> grid that will serve as displays for each player
		{
			row=[];
			for(j=0;j<4;j++)
			{
				currentPix=scoreNumbers[0][i][j];		
				pixel=document.createElement("div");
				pixel.className="pixel";
				pixel.style.top=i*30+"px";
				pixel.style.left=j*30+"px";
				if(currentPix){
					pixel.style.opacity=1;
				}
				else {
					pixel.style.opacity=0;
				}
				row.push(pixel)
				pScore.appendChild(pixel)
			}
			if(p==1) p1Display.push(row);
			else p2Display.push(row);
		}
		
		field.appendChild(pScore);
	
		
	}
}
function manageBall(){

	ball.x+=ball.speed*ball.hDir;
	ball.y+=ball.speed*ball.vDir;
	
	if(ball.y+30>800 || ball.y<0){					//ball rebounds against walls
		ball.vDir=-ball.vDir;
		if(ball.y<=0) ball.y=0;						//avoid ball going through walls
			else if(ball.y>770) ball.y=770;
	}

//COLLISIONS

	if(ball.x<80 && ball.x>50 && ball.hDir<0){			//We check that the ball is in the player1 area and that is going to the left
	
		if(ball.y+30>player1.y && ball.y<player1.y+playerHeight)		//This checks that the ball touches the paddle
		{
			ball.hDir=-ball.hDir*1.1;									//Changes the horizontal direction of the ball and adds speed
			ball.vDir=((playerHeight-(player1.y-(ball.y))-playerHeight-30)/playerHeight)*2;
			//adjusts the angle of rebound depending on the vertical point where it touched the paddle (Could need a little bit of tweaking)
		}
	
	}
	else {
		if(ball.x>850 && ball.x<880 && ball.hDir>0) //Same as with player1 but with player2
		{
			if(ball.y+30>player2.y && ball.y<player2.y+playerHeight)
			{
				ball.hDir=-ball.hDir*1.1;
				ball.vDir=((playerHeight-(player2.y-(ball.y))-playerHeight-30)/playerHeight)*2;		
			}
			
		}
	}

	if(ball.x+30>960 || ball.x<0){		//Checks that it's a goal and updates score, also makes the ball rebound & slow it down
		if (ball.hDir>0){
			updateScore(1);
			ball.hDir=-ball.hDir/2;		
			if(ball.hDir>-1) ball.hDir=-1; //avoid the ball being too slow
			ball.x=930;
		}
		else {
			updateScore(2);
			ball.hDir=1;
			ball.hDir=-ball.hDir/2;		
			if(ball.hDir<1) ball.hDir=1; //avoid the ball being too slow
			ball.x=0;
		}
		
		
	}
		
	if(ball.hDir<-5) ball.hDir=-5;
	if(ball.hDir>5) ball.hDir=5;		// We control the maximum speed of the ball

	ball.style.left=ball.x+"px";		//We position the ball in every frame
	ball.style.top=ball.y+"px";	
}

function frame(){

	managePlayers();				//in every frame we manage players and ball
		manageBall();
	
}

function managePlayers(){
	if(keys[0]) player1.vSpeed-=2;				//map controls to acceleration
	if(keys[1]) player1.vSpeed+=2;	
	if(keys[2]) player2.vSpeed-=2;
	if(keys[3]) player2.vSpeed+=2;
		
	if(player1.vSpeed>12) player1.vSpeed=12;	//Limit the max speed
	if(player1.vSpeed<-12) player1.vSpeed=-12;
	if(player2.vSpeed>12) player2.vSpeed=12;
	if(player2.vSpeed<-12) player2.vSpeed=-12;
		
		
	
	player1.y+=Math.round(player1.vSpeed);	//transport speed to movement P1
	player2.y+=Math.round(player2.vSpeed);	//transport speed to movement P2
	
	if(player2.y<0){
			player2.y=0;
			if(player2.vSpeed<-1) player2.vSpeed=-player2.vSpeed*0.5; //bounce against the wall
	}
	if(player2.y+playerHeight>800)
		{
			player2.y=800-playerHeight;
			player2.vSpeed=-player2.vSpeed*0.5; //bounce against the wall
			
		}
	
			
		
		
	if(player1.y<0)							//Collision with top wall
		{
			player1.y=0;						//Adjust coords so it doesn't go through wall
			player1.vSpeed=-player1.vSpeed*0.5; //bounce against the wall
		}
	
	if(player1.y+playerHeight>800){			//Collision with bottom wall
			player1.y=800-playerHeight;			//Adjust coords so it doesn't go through wall
			player1.vSpeed=-player1.vSpeed*0.5;	//bounce against the wall
		}
	
	
	player1.vSpeed=player1.vSpeed*0.9; 		//friction P1
	player2.vSpeed=player2.vSpeed*0.9;		//friction P2
	
	
	player1.style.top=Math.floor(player1.y)+"px"; //place paddles where they belong
	player2.style.top=Math.floor(player2.y)+"px"; 
	
	
	
}

function handleDown(e){						//This controls key pressed and sets key array values to true
	
	var pressedKey = e.keyCode;
	
	if(pressedKey==player1.kup)
	{
		keys[0]=true;
		
	}
	else 
	{
		if(pressedKey==player1.kdown){
			keys[1]=true;
		}
		else {
			if(pressedKey==player2.kup)
			{
				keys[2]=true;
				
			}
			else 
			
			{
				if(pressedKey==player2.kdown) 
				keys[3]=true;
			}
		}
	}
	
	
}

function handleUp(e){						//This controls key de-pressed and sets key array values to false
	
	var pressedKey = e.keyCode;
	
	if(pressedKey==player1.kup)
	{
		keys[0]=false;
	}
	else 
	{
		if(pressedKey==player1.kdown) 
		{
			keys[1]=false;
		}
		else {
			if(pressedKey==player2.kup)
			{
				keys[2]=false;
				
			}
			else 
			
			{
				if(pressedKey==player2.kdown) 
				keys[3]=false;
			}
		}
	}
}

function main(){
												//initialize elements
	playerHeight=100;							//This is will come handy in subsequent versions. Ignore
	
	player1.vSpeed=0;							//init players
	player2.vSpeed=0;
	
	player1.kup="81";							//define player controls with keycodes: Player 1 = Q for UP and A for DOWN
	player1.kdown="65";
	
	player2.kup="79";							//define player controls with keycodes: Player 2 = O for UP and K for DOWN
	player2.kdown="75";
	
	ball.speed = 5;								//this controls the global ball speed. Don't change right now or bad things will happen (collisions with players will fail)	

	createScores();								// this initializes the player displays with the fancy <div> grid
	
	ball.x=500;												
	ball.y=50;									//place the ball and initialize values
	ball.vDir=0;
	ball.hDir=-1;
	
	player1.x=30;								//place players
	player1.y=0;
	player2.x=30;
	player2.y=0;
	
	player1.style.height=playerHeight;						//this will come handy later when making the game more dynamic
	
	document.addEventListener("keydown", handleDown)		//add the key listeners
	document.addEventListener("keyup", handleUp)										
	
	
}

main();

function start () {
	setInterval(frame, 1000/30);				//call the main game loop
}