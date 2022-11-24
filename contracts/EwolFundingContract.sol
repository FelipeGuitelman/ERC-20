// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract CrowdFund is ERC20, Ownable {
    address _owner;
    uint TOKEN_PRICE = 1 ether;

    //Estos eventos se emiten (emite) con cada función o paso que se vaya dando
    event Launch(address indexed caller, uint amount, uint startDate, uint finishDate);
    event Cancel(uint actualDate, address indexed caller, string reason);
    event Pledge(address indexed caller, uint amountPledged, uint actualDate);
    event Claim(uint actualDate, uint amount);
    event Refund(address indexed caller, uint amount);

    // Estructura de la newCampaign
    struct Campaign {
        address creator; // Creator of campaign
        uint goal;// Amount of tokens to raise
        uint pledged; // Total amount pledged
        uint32 startAt;// Timestamp of start of campaign
        uint32 endAt;// Timestamp of end of campaign
        bool claimed;// True if goal was reached and creator has claimed the tokens.
        bool launched; // True if campaign has started
    }

    Campaign newCampaign;

    mapping (address => uint) pledgedByAddress;

    //Aca nosotros vamos a CREAR el token y mintear una cantidad X
    // Vamos a permitirle al owner generar mas tokens si se agotó la cant inicial?
      constructor (uint256 initialSupply) ERC20("EwolCrowfunding", "EWC") {
        _owner = msg.sender;
        _mint(address(this), initialSupply);
    }

    // El Owner debería poder "iniciar" el crowfunding / Definiendo variables de newCampaign Struct
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) public onlyOwner {
        
        require(newCampaign.launched == false, "Campaign is already running");
        require(_startAt >= block.timestamp, "Cannot initialize on a past date");
        require(_endAt > _startAt, "Cannot end before it starts");
        require(_goal <= balanceOf(address(this)), "Not enough tokens for this goal.");

        newCampaign.creator = _owner;
        newCampaign.pledged = 0;
        newCampaign.goal = _goal;
        newCampaign.startAt = _startAt;
        newCampaign.endAt = _endAt;
        newCampaign.claimed = false;
        newCampaign.launched = true;

        emit Launch(msg.sender, _goal, _startAt, _endAt);
    }

    // Si el owner quiere, antes de empezar el tiempo, debe poder cancelarlo.
    // onlyOwner
    function cancel (string memory reason) public onlyOwner {

        require(block.timestamp < newCampaign.startAt, "Campaign has already started");
        require(newCampaign.pledged == 0, "Campaign had sold tokens");
        
        newCampaign.launched = false;
        emit Cancel(block.timestamp, msg.sender, reason);
    }
    

    // Si esta dentro de los tiempos, tiene que permitir "comprar" Tokens.
    // Envia ETH, recibe a cambio el TOKEN. Definir el precio.
    // requier fehca actual este entre fecha de inicio y fin de la newCampaign
    function pledge (uint amountToBuy) public payable {
        require(block.timestamp >= newCampaign.startAt, "This Campaign didnt start");
        require(block.timestamp < newCampaign.endAt, "This Campaign has finished");
        require(newCampaign.launched  == true, "This Campaign is not active");
        require(msg.value == amountToBuy * TOKEN_PRICE, "Wrong Amount of Ether sent");
        uint tokenAvailables = newCampaign.goal - newCampaign.pledged;

        require(tokenAvailables >= amountToBuy, "Not enough Tokens Availables");
            
        this.transfer(msg.sender, amountToBuy);
        
        // safeTransfer("EWC", msg.sender, amountToBuy) - PREGUNTAR A ADRIAN PORQUE NO ÉSTA. O COMO USARLA.

        pledgedByAddress[msg.sender] += amountToBuy;
        newCampaign.pledged += amountToBuy;

        emit Pledge(msg.sender, amountToBuy, block.timestamp);

    } 
    

    //Si terminó el plazo y se llegó al monto, el owner puede retirar los ETH recaudados
    // onlyOwner

    function claim() external payable onlyOwner {
        require(block.timestamp > newCampaign.endAt, "Campaign is still running");
        require(newCampaign.pledged >= newCampaign.goal, "Campaign didnt reach the Goal");

        uint _ethBalance = address(this).balance;
        payable(msg.sender).transfer(_ethBalance);

        emit Claim(block.timestamp, _ethBalance);

    }

    //Si se terminó el plazo y NO se llegó al monto, los users pueden pedir REFUND.
    // Devuelven los TOKENS ? y reciben ETH previamente entregados
    // el owner hace BURN de los tokens?
    function refund() external payable {
        require(block.timestamp > newCampaign.endAt, "Campaign is still running");
        require(newCampaign.pledged < newCampaign.goal, "Campaign passed the goal");
        require(balanceOf(msg.sender) == pledgedByAddress[msg.sender], "You dont have the tokens");

        uint amountToRefund = pledgedByAddress[msg.sender] * TOKEN_PRICE;

        this.transfer(msg.sender, amountToRefund);
        //msg.sender.transfer(address(this), amountToRefund);

        //payable(address(this)).transfer(amountToRefund);
        //PREGUNTAR A ADRIAN COMO DEVOLVER TOKEN A CONTRATO
        // Y ETH A CADA USER QUE APORTÓ
        
        emit Refund(msg.sender, pledgedByAddress[msg.sender]);
    
    }
}
