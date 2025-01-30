#pragma version ~=0.4.0
#pragma evm-version cancun
#pragma optimize gas

interface ERC20:
  def name() -> String[64]: view
  def symbol() -> String[8]: view
  def decimals() -> uint8: view
  def totalSupply() -> uint256: view
  def balanceOf(_owner: address) -> uint256: view
  def transfer(_to: address, _value: uint256) -> bool: nonpayable
  def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
  def approve(_spender: address, _value: uint256) -> bool: nonpayable
  def allowance(_owner: address, _spender: address) -> uint256: view

event Transfer:
  _from: indexed(address)
  _to: indexed(address)
  _value: uint256

event Approval:
  _owner: indexed(address)
  _spender: indexed(address)
  _value: uint256

active: public(bool)
shitCoin: public(immutable(ERC20))
decimals: public(immutable(uint8))
timeToBuy: public(immutable(uint256))
totalHolders: public(uint256)
lastDepositTime: public(HashMap[address, uint256])

@deploy
def __init__(coin: address, time: uint256):
  shitCoin = ERC20(coin)
  decimals = staticcall shitCoin.decimals()
  timeToBuy = time

# ERC20 functions

name: public(constant(String[64])) = "skid mark: a streak of shit"
symbol: public(constant(String[8])) = "SKIDMARK"
totalSupply: public(uint256)
balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])

@internal
def _transfer(_from: address, _to: address, _amount: uint256) -> bool:
  balanceFrom: uint256 = self.balanceOf[_from]
  if balanceFrom < _amount:
    return False
  self.balanceOf[_from] = unsafe_sub(balanceFrom, _amount)
  self.balanceOf[_to] = self.balanceOf[_to] + _amount
  fromEmptied: bool = 0 < balanceFrom and self.balanceOf[_from] == 0
  toStarted: bool = 0 < _amount and self.lastDepositTime[_to] == 0
  if toStarted:
    self.lastDepositTime[_to] = self.lastDepositTime[_from]
    if not fromEmptied:
      self._increaseHolders()
  elif fromEmptied:
    self._decreaseHolders(_from)
  log Transfer(_from, _to, _amount)
  return True

@external
def transfer(_to: address, _value: uint256) -> bool:
  return self._transfer(msg.sender, _to, _value)

@internal
def _approve(_owner: address, _spender: address, _value: uint256) -> bool:
  self.allowance[_owner][_spender] = _value
  log Approval(_owner, _spender, _value)
  return True

@external
def approve(_spender: address, _value: uint256) -> bool:
  return self._approve(msg.sender, _spender, _value)

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
  allowanceFrom: uint256 = self.allowance[_from][_to]
  if allowanceFrom < _value:
    return False
  transferred: bool = self._transfer(_from, _to, _value)
  if transferred:
    self.allowance[_from][_to] = unsafe_sub(allowanceFrom, _value)
  return transferred

event Mint:
  amount: indexed(uint256)
  holder: indexed(address)

event Kill:
  amount: indexed(uint256)
  killer: indexed(address)
  victim: indexed(address)

event Raid:
  amount: indexed(uint256)
  reward: indexed(uint256)
  winner: indexed(address)

@internal
def _increaseHolders():
  self.totalHolders += 1
  if not self.active and 1 < self.totalHolders:
    self.active = True

@internal
def _decreaseHolders(who: address):
  self.totalHolders -= 1
  self.lastDepositTime[who] = 0
  if self.active and self.totalHolders == 0:
    self.active = False

@external
def mint(amount: uint256, recipient: address):
  assert 0 < amount
  assert extcall shitCoin.transferFrom(msg.sender, self, amount)
  self.totalSupply += amount
  self.balanceOf[recipient] += amount
  if self.lastDepositTime[recipient] == 0:
    self._increaseHolders()
  self.lastDepositTime[recipient] = block.timestamp
  log Mint(amount, recipient)

@external
def kill(target: address):
  assert timeToBuy < block.timestamp - self.lastDepositTime[target]
  amount: uint256 = self.balanceOf[target]
  assert 0 < amount
  self.totalSupply -= amount
  self.balanceOf[target] = 0
  self._decreaseHolders(target)
  log Kill(amount, msg.sender, target)

@external
def raid():
  assert self.totalHolders == 1
  assert self.lastDepositTime[msg.sender] != 0
  assert self.active
  reward: uint256 = staticcall shitCoin.balanceOf(self)
  assert extcall shitCoin.transfer(msg.sender, reward)
  amount: uint256 = self.balanceOf[msg.sender]
  self.totalSupply -= amount
  self.balanceOf[msg.sender] = 0
  self._decreaseHolders(msg.sender)
  log Raid(amount, reward, msg.sender)
