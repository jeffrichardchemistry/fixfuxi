# fixfuxi
Um script para resolver problemas de audio e microfone do headset fixfuxi e potenciais outros headsets sem fio no linux.


# USB Headset Audio Fix (Linux / PipeWire)

Correção automática para problemas comuns de **headsets USB no Linux**, especialmente em sistemas que utilizam **PipeWire + WirePlumber**.

Este projeto ajusta o comportamento do sistema de áudio para garantir funcionamento correto de headsets USB gamer, tanto **via cabo** quanto **via dongle wireless**.

---

## Problemas que este projeto resolve

Alguns headsets USB apresentam falhas no Linux devido a limitações do mixer interno do dispositivo. Entre os problemas mais comuns:

- áudio funcionando apenas em **um lado do headset**
- **microfone iniciando zerado**
- falhas ao **reduzir o volume do sistema**
- problemas ao alternar entre **modo USB e wireless**
- dispositivo entrando em **suspensão automática**
- PipeWire configurando canais de áudio incorretamente

---

## Como funciona

A solução ajusta a política de áudio do **PipeWire/WirePlumber**, fazendo com que o sistema utilize **controle de volume em software** em vez do mixer interno do headset.

Isso evita problemas comuns em dispositivos USB que possuem mixers defeituosos ou incompletos.

Com isso o sistema passa a ter:

- áudio estéreo funcionando corretamente  
- microfone estável após reinicialização  
- troca entre **USB e wireless** sem falhas  
- volume do sistema funcionando normalmente  

---

## Compatibilidade

Funciona em distribuições Linux modernas que utilizam **PipeWire**, como:

- Ubuntu
- Linux Mint
- Fedora
- Arch Linux
- Pop!_OS
- Nobara
- Garuda
- outras distribuições baseadas em PipeWire

---

## Dispositivos suportados

Embora tenha sido criado para o **Fuxi H3**, o projeto funciona com a maioria dos **headsets USB gamer**, incluindo:

- headsets USB com fio  
- headsets wireless com dongle USB  
- dispositivos identificados como **USB Audio**

---

## Quando usar

Use este projeto se seu headset apresentar:

- áudio apenas em um lado  
- microfone que para de funcionar  
- problemas ao alterar volume  
- falhas ao alternar entre cabo e wireless 
