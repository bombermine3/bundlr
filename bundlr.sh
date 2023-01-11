#!/bin/bash

curl -s https://raw.githubusercontent.com/bombermine3/cryptohamster/main/logo.sh | bash && sleep 1

if [ $# -ne 1 ]; then 
	echo "Использование:"
	echo "bundlr.sh <command>"
	echo "	install   Установка ноды"
	echo "	uninstall Удаление"
	echo "	update    Обновление"
	echo "	backup    Бэкап приватного ключа"
	echo ""
fi

case "$1" in
install)
	apt update && apt -y upgrade
	apt install -y curl git wget build-essential libssl-dev pkg-config libpq-dev jq
	apt -qq -y purge docker docker-engine docker.io containerd docker-compose
	rm /usr/bin/docker-compose /usr/local/bin/docker-compose
	curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && systemctl restart docker
	curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose && ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	source "$HOME/.cargo/env"
	curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - && sudo apt-get install -y nodejs
	
	git clone --recurse-submodules https://github.com/Bundlr-Network/validator.git bundlr
	cd bundlr

	tee $HOME/bundlr/.env > /dev/null <<EOF
PORT=42069   
BUNDLER_URL=https://testnet1.bundlr.network
GW_CONTRACT="RkinCLBlY4L5GZFv8gCFcrygTyd5Xm91CzKlR6qxhKA"
GW_ARWEAVE=https://arweave.testnet1.bundlr.network
GW_STATE_ENDPOINT=https://faucet.testnet1.bundlr.network
EOF

	npm i -g @bundlr-network/testnet-cli
	
	cargo run --bin wallet-tool create > wallet.json

	ADDRESS=$(cargo run --bin wallet-tool show-address --wallet ./wallet.json 2>/dev/null | jq .address | tr -d '"')
	echo "Запросите токены из крана https://bundlr.network/faucet"
	echo "Адрес: ${ADDRESS}"

	read -p "\nНажмите Enter для проверки баланса"
 	
	BALANCE=0
	while [ "$BALANCE" == "0" ] 
	do
		BALANCE=$(testnet-cli balance $ADDRESS 2>&1 | grep -oP "Balance of address (.*) - \K\d+")
		sleep 5
	done

	docker-compose up -d
	testnet-cli join RkinCLBlY4L5GZFv8gCFcrygTyd5Xm91CzKlR6qxhKA -w ./wallet.json -u "http://$(curl -s ifconfig.me):42069" -s 25000000000000

	echo "Установка завершена"	
	;;

uninstall)
	cd $HOME/bundlr && docker-compose down -v
	cd $HOME && rm -rf $HOME/bundlr
	echo "Удаление завершено"
	;;

backup)
	
	;;

update)
	cd $HOME/bundlr
	git pull origin master && git submodule update --init --recursive && docker-compose up -d
	;;
esac