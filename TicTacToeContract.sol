pragma solidity ^0.5.13;

/* TicTacToe Gambling Smart Contract
 * %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 * All of the fun and fear of TicTacToe and Exit scams
 * To start a game deposit at least 1 ETH and join the game
 * One of the last two players will drain the entire contract.
 * ____________________________________________________________________________
 * For visual purposes please inspect the site (Chrome) and add the following 
 * CSS properties to the body of remix so that the board is properly displayed: 
 * font-family: monospace;
 * white-space: pre-wrap;
 * ____________________________________________________________________________
 */


contract TicTacToe {
    // Addresses
    address owner;
    address timeWinner;
    address payable player1;
    address payable player2;
    
    // Instance of a temporairly banned player
    address payable ban;
    
    // Waiting slots
    bool player1Defined = false;
    bool player2Defined = false;
    
    // Game States
    bool paidOut = true;
    bool won = false;
    bool playersHaveMoved = false;
    bool firstTimeLimit = false;
    bool joinLimit = false;
    uint count = 0;

    // Time to make a move
    uint timeframe = 40;
    
    // Time to redeem the Ether
    uint golden_timeframe = 120;
    
    // Time to start after two players have joined
    uint startingTimeFrame = 20;
    
    // 48 hour countdown
    uint gameTimeFrame = 172800;
    
    // Timers
    uint256 timelimit;
    uint256 join_timelimit;
    uint256 golden_timelimit = block.timestamp + gameTimeFrame;
    uint256 game_timelimit = block.timestamp + gameTimeFrame;
    
    // Semi-random numbers with initial salt
    uint randomNumber;
    uint salt = 15861354222536;
    
    // Account balances and temporary bans
    mapping(address => uint) balances;
    mapping(address => bool) banned;
    
    // TicTacToe Board States
    enum states {Empty, O, X}
    states[3][3] board;
    
    /* A board with different states 
     * 0, 1, 2          O, O, X
     * 3, 4, 5          O, X, -
     * 6, 7, 8          X, -, -
     * columns are the x and rows are the y positions
     */
    
    event Error(string message);
     
    constructor() public {
        
        // Map owner address
        owner = msg.sender;

    }
    
    modifier playersDefined {
        // Slots have to be occupied
        require(player1Defined == true && player2Defined ==true, "Not all players are specified");
        _;
    }
    
    modifier playersMoved {
        // Players have made a move or the first timer went off
        require(player1Defined == true && player2Defined ==true && (playersHaveMoved == true || (firstTimeLimit == true && remainingTime() == 0) ), "Nobody has lost so far");
        _;
    }
    
    modifier playerSent{
        // Command sent from one of the players
        require(msg.sender == player1 || msg.sender == player2, "Only players can execute this command");
        _;
    }
    
    modifier has_value {
        // Transaction has value
        require(msg.value > 0);
        _;
    }
    
    modifier notBanned {
        // Player not banned
        require(banned[msg.sender] == false, "You are temporairly banned");
        _;
    }
    
    modifier has_balance {
        // Player has enough balance
        require(balances[msg.sender] >= 1 ether, "Please deposit at least 1 ether");
        _;
    }
    
    function deposit() external payable has_value{
        
        /*     Allows to deposit funds
         */
        
        balances[msg.sender] += msg.value;
    }
    
    function myBalance() public view returns (uint256){
        
        /*     Shows the current balance
         */
        
        return (balances[msg.sender]);
    }
    
    function showJackpot() public view returns (uint256){
        
        /*     Shows the current Jackpot
         */
        
        return (address(this).balance);
    }
    
    function join() has_balance notBanned public{
        
        /*     To join the game: 1 ETH
         */
         
        // Checks whether player is occupying slot without starting a game
        if (joinClock()==0 && joinLimit==true){
            banned[player2] = true;
            ban = player2;
            player2Defined = false;
            joinLimit=false;
            balances[player2] = 0 ether;
        }
        
        if (msg.sender == player1 || msg.sender == player2){
            revert("You are already enrolled!");
        }
        
        // Fills slot 1
        else if (player1Defined == false){
            player1 = msg.sender;
            player1Defined = true;
        }
        
        // Fills slot 2
        else if (player2Defined == false){
            player2 = msg.sender;
            player2Defined = true;
            join_timelimit = block.timestamp + startingTimeFrame;
            joinLimit=true;
        }
        else{
            revert("Currently a game is running!");
        }
        // Costs 1 ETH
        balances[msg.sender] -= 1 ether;
    }
        
    function start() playersDefined playerSent public{
        
        /*     Starts the game when two players have joined
         */
        
        require(gameIsOn() == false, "The game has already begun");
        require(paidOut==true || goldenClock() == 0);
        
        // Start the clock
        timelimit = block.timestamp + timeframe;
        firstTimeLimit = true;
        paidOut = false;
        joinLimit=false;
    }
    
    function stop() playersDefined playerSent public{
        
        /*     Stops the game and starts lottery 
         *      if the last game was some time ago
         */
        
        require(gameIsOn() == false, "The game has already begun");
        require(paidOut == false, "You have already been paid out");
        
        // Winner receives 75% of the funds
        winner().transfer(1.5 ether);
        paidOut = true;
        lottery(player1, player2);
        player1 = address(0);
        player2 = address(0);
        
        // Resets variables and the temporary ban 
        banned[ban] = false;
        player1Defined = false;
        player2Defined = false;
        playersHaveMoved = false;
        firstTimeLimit = true;
        game_timelimit = block.timestamp + gameTimeFrame;
        golden_timelimit = block.timestamp + gameTimeFrame;
        count = 0;
    }
    
    function lottery(address payable _player1, address payable _player2) private{
        
        /*     Starts a lottery between the last two players
         */
        
        // Creates semi-random number through salted hash
        randomNumber = uint(keccak256(abi.encodePacked(blockhash(block.number), salt)));
        
        // Changes salt
        salt ++;
        
        // If countdown has finished contract is drained to one of the players and selfdestructs
        if (lastGame()==0){
            if (randomNumber%2 == 0){
                _player1.transfer(address(this).balance);
                selfdestruct(_player1);
                
            }
            else if (randomNumber%2 == 1){
                _player2.transfer(address(this).balance);
                selfdestruct(_player2);
            }
        }
    }
        
    function remainingTime() public view returns (uint256){
        
        /*     Shows the remaining time for a move
         */
        
        if (timelimit>block.timestamp){
        return (timelimit-block.timestamp);
        }
        else{
        return 0;
        }
    }
    
    function joinClock() private view returns (uint256){
        
        /*     Returns the remaining time to start the game
         */
        
        require(gameIsOn() == false, "The game has already begun!");
        if (join_timelimit>block.timestamp){
        return (join_timelimit-block.timestamp);
        }
        else{
        return 0;
        }
    }
    
    function goldenClock() public view returns (uint256){
        
        /*     Shows the remaining time to get the winnings
         */
        
        require(gameIsOn() == false, "The golden clock starts ticking as soon as someone won!");
        require(paidOut == false, "The winner was already paid");
        if (golden_timelimit>block.timestamp){
        return (golden_timelimit-block.timestamp);
        }
        else{
        return 0;
        }
    }
    
    function lastGame() private view returns (uint256){
        
        /*     Shows the remaining time
         */
        
        if (game_timelimit>block.timestamp){
        return (game_timelimit-block.timestamp);
        }
        else{
        return 0;
        }
    }
    
    function positionIsInBounds(uint8 xpos, uint8 ypos) private pure returns (bool){
        
        /*     Checks whether a position tuple is in bounds of the board
         *      pure: Does not read from or modify the states
         */
         
        return (xpos >= 0 && xpos < 3 && ypos >= 0 && ypos < 3);
    }
    
    function squareToString(uint8 xpos, uint8 ypos) private view returns (string memory){
        
        /*     Returns the state of a single position as a string
         */
         
        require(positionIsInBounds(xpos,ypos), "Out of bounds");
        
        // Searches for state at given position
        if (board[xpos][ypos] == states.Empty){
            return " ";
        }
        if (board[xpos][ypos] == states.X){
            return "X";
        }
        if (board[xpos][ypos] == states.O){
            return "O";
        }
    }
    
    function rowToString(uint8 ypos) private view returns (string memory){
        
        /*     Returns a row as a string
         */
         
        return string(abi.encodePacked(squareToString(0, ypos), "|", squareToString(1, ypos), "|", squareToString(2, ypos)));
    }
    
    function drawBoard() public view returns (string memory){

 	    /*     Returns entire board as a string
         */
         
        // Concatenates row strings to a single TicTacToe board
        return string(abi.encodePacked("\n",
            rowToString(0), "\n",
            rowToString(1), "\n",
            rowToString(2), "\n"
        ));
    }
    
    
    function makeMove(uint8 xpos, uint8 ypos) public {

	    /*     Makes a move when requirements are met:
         */
        
	    // Can only be executed by players
        require (msg.sender == player1 || msg.sender == player2, "You are not part of this game!");
	
	    // Can only be executed by current player
        require (msg.sender == currentPlayer(), "It is not your turn!");

	    // Game is not over
        require (gameIsOn(), "The game is over!");

	    // The specified position is in the bounds
        require (positionIsInBounds(xpos, ypos), "The specified position is not in range!");

	    // The specified position is empty
        require (board[xpos][ypos] == states.Empty, "The specified position is not empty!");
        
        // Makes sure to start the first timer
	    firstTimeLimit = false;
	    playersHaveMoved = true;
	    
	    // If the time has not run out
	    if (block.timestamp <= timelimit){
	        // The specified position is filled with the according shape
            board[xpos][ypos] = currentPlayerShape();
    
    	    // The game count is incremented
            count = count + 1;
            
            // The time limit is reset
            timelimit = block.timestamp + timeframe;
            golden_timelimit = block.timestamp + golden_timeframe;
	    }
    }
        
        
    function winningPlayerShape() private view returns (states) {
        
        /*     Checks the board for a victory and returns the winning state
         */
        
        // Checks all columns
        if (board[0][0] != states.Empty && board[0][0] == board[0][1] && board[0][0] == board[0][2]){
            return board[0][0];
        }
        
        if (board[1][0] != states.Empty && board[1][0] == board[1][1] && board[1][0] == board[1][2]){
            return board[1][0];
        }
        
        if (board[2][0] != states.Empty && board[2][0] == board[2][1] && board[2][0] == board[2][2]){
            return board[2][0];
        }
        
        // Checks all rows
        if (board[0][0] != states.Empty && board[0][0] == board[1][0] && board[0][0] == board[2][0]){
            return board[0][0];
        }
        
        if (board[0][1] != states.Empty && board[0][1] == board[1][1] && board[0][1] == board[2][1]){
            return board[0][1];
        }    
        
        if (board[0][2] != states.Empty && board[0][2] == board[1][2] && board[0][2] == board[2][2]){
            return board[0][2];
        }
        
        //Checks the diagonals 
        if (board[0][0] != states.Empty && board[0][0] == board[1][1] && board[0][0] == board[2][2]){
            return board[0][0];
        }
        
        if (board[0][2] != states.Empty && board[0][2] == board[1][1] && board[0][2] == board[2][0]){
            return board[0][0];
        }
        
        else{
            return states.Empty;
        }
    }
    
    function gameIsOn() public view returns (bool){
        
        /*     Determines if the game is on or over
         */
        
        return (winningPlayerShape() == states.Empty && count < 9 && remainingTime()>0);
    }
    
    function winner() playersMoved public view returns (address payable) {
        
        /*     Returns the winning address
         */
        
        // If the time passed the winner is already determined
        if (remainingTime()==0){
            return oppositePlayer();
        }
        
        // Checks the winning shape
        states winning_shape = winningPlayerShape();
        
        if (winning_shape == states.X){
            return player1;
        }
        
        else if (winning_shape == states.O){
            return player2;
        }
        
        return address(0);
    }
    
    
    function currentPlayer() public view returns (address payable){
        
        /*     Returns the current player address
         */
        
        //All even turns are player1
        if (count % 2 == 0) {
            return player1;
        }
        
        //All odd turns are player2
        else {
            return player2;
        }
    }
    
    function currentPlayerShape() private view returns (states){
        
        /*     Returns the current player shape
         */
        
        //All even turns are O
        if (count % 2 == 0) {
            return states.O;
        }
        
        //All odd turns are X
        else {
            return states.X;
        }
    }
    
    function oppositePlayer() public view returns (address payable){
        
        /*     Returns the current player address
         */
        
        //All even turns are player2
        if (count % 2 == 0) {
            return player2;
        }
        
        //All odd turns are player1
        else {
            return player1;
        }
    }
}