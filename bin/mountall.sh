#!/bin/bash
#
# Namountuje vzdalene jednotky
#

########## KONFIGURACE ##########
DATFILE="data/mount_servers.dat";

########## FUNKCE ##########

# Pripojeni serveru
function _mount() {
	SERVER_DIR=/home/$USER/mnt/$USER@$1
	SHARE_DIR=/home/$USER/mnt/$USER@$1/$2
	SHARE_DEVICE=$USER@$1/$2

	if [ ! -d $SERVER_DIR ]; then
		echo "Vytvarim adresar... ${SERVER_DIR}";
		mkdir -p $SERVER_DIR;
	fi

	if [ ! -d $SHARE_DIR ]; then
		echo "Vytvarim adresar... ${SHARE_DIR}";
		mkdir -p $SHARE_DIR;
	fi

	echo "Pripojuji jednotku... ${SHARE_DEVICE}";
	sudo mount //$1/$2 $SHARE_DIR -o user=$USER,iocharset=utf8,file_mode=0777,dir_mode=0777
};

# Odpojeni serveru
function _unmount() {
	SERVER_DIR=/home/$USER/mnt/$USER@$1
	SHARE_DIR=/home/$USER/mnt/$USER@$1/$2
	SHARE_DEVICE=$USER@$1/$2

	echo "Odpojuji jednotku... ${SHARE_DEVICE}";
	sudo umount $SHARE_DIR;

	echo "Mazu adresar... ${SHARE_DIR}";
	rmdir $SHARE_DIR;

	DRIVES_COUNT=$(ls -l $SERVER_DIR | grep ^d | wc -l);
	if [ $DRIVES_COUNT == 0 ]; then
		echo "Mazu adresar... ${SERVER_DIR}";
		rmdir $SERVER_DIR;
	fi
};

# Vypise radek
function _echo() {
	echo "Server: ${1}; Vzdalene sdileni: ${2}";
};

# Vypise napovedu
function _help() {
	echo "
	Pripoji pomoci prikazu mount vzdalena Windows sdileni ze souboru ${DATFILE} do adresare /home/${USER}/mnt/[uzivatel@server]

	Pouziti: ${0} [PARAMETR]

	Seznam parametru:
	-m       Pripoji vzdalena sdileni
	-u       Odpoji vzdalena sdileni
	-e       Vypise seznam sdileni k pripojeni
	-help    Vypise napovedu

	Dalsi informace:
	Seznam sdileni naleznete v souboru: ${DATFILE}
	Zadavejte vzdy na novy radek je v poradi: server [VZDALENE SDILENI]
	Script pocita pro prihlaseni do Windows se stejnym uzivatelskym jmenem, pod kterym jste v linuxu.";

	exit 1;
};

# Chyba - spatne zadane parametry
function _badParameters() {
	echo "
	Error: Scriptu byly predany spatne zadane parametry.
	Pro vypsani napovedy pouzijte: ${0} -help";
	exit 1;
};

# Chyba - nulova velikost souboru se seznamem serveru
function _noServers() {
	echo "Error: Nejprve je nutne zapsat seznam sdileni k pripojeni do souboru ${DATFILE}";
	exit 1;
};

########## ZACATEK BEHU SCRIPTU ##########

# Kontrola adresare s daty
if [ ! -d data ]; then
	mkdir data;
fi

# Kontrola adresare pro pripojeni serveru
if [ ! -d /home/$USER/mnt ]; then
	mkdir /home/$USER/mnt;
fi

# Kontrola existence seznamu serveru
if [ ! -f $DATFILE ]; then
	touch $DATFILE;
	_noServers;
fi

# Kontrola velikosti souboru se seznamem serveru
if [ ! -s $DATFILE ]; then
	_noServers;
fi

# Prepinac pro script
PAR=$1;

# Kontrola, zda byl predan vubec nejaky parametr
if [ ! $PAR ]; then
	PAR="?";
fi

# Projdeme radek po radku v souboru se seznamem serveru
SERVER_LIST="/home/${USER}/bin/${DATFILE}"
cat $SERVER_LIST | while read LINE; do
	if [ $PAR == "-m" ]; then
		_mount $LINE
	elif [ $PAR == "-u" ]; then
		_unmount $LINE;
	elif [ $PAR == "-e" ]; then
		_echo $LINE;
	elif [ $PAR == "-help" ]; then
		_help;
	else
		_badParameters;
	fi
done

# Konec scriptu
