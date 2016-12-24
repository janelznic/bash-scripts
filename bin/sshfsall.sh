#!/bin/bash
#
# Namountuje vzdalene jednotky
#

########## KONFIGURACE ##########
DATFILE="data/sshfs_servers.dat";

########## FUNKCE ##########

# Pripojeni serveru
function _mount() {
	mkdir -p /home/$USER/mnt/$1;

	echo "Pripojuji..." $1;
	sshfs $1:$2 /home/$USER/mnt/$1 -o reconnect -o transform_symlinks -o follow_symlinks -o uid=1000 -o workaround=rename -o allow_other;
};

# Odpojeni serveru
function _unmount() {
	echo "Odpojuji..." $1;
	fusermount -u /home/$USER/mnt/$1;

	rmdir /home/$USER/mnt/$1;
};

# Vypise radek
function _echo() {
	DIR=$2;
	if [ ! $DIR ]; then
		DIR="/home/${USER}";
	fi
	echo "Server: ${1}; Vzdaleny adresar: ${DIR}";
};

# Vypise napovedu
function _help() {
	echo "
	Pripoji pomoci SSHFS vzdalene servery ze souboru ${DATFILE} do adresare /home/${USER}/mnt/[uzivatel@server]

	Pouziti: ${0} [PARAMETR]

	Seznam parametru:
	-m       Pripoji vzdalene servery
	-u       Odpoji vzdalene servery
	-e       Vypise seznam serveru k pripojeni
	-help    Vypise napovedu

	Dalsi informace:
	Seznam serveru naleznete v souboru: ${DATFILE}
	Zadavejte vzdy na novy radek je v poradi: uzivatel@server [VZDALENY ADRESAR]
	Pokud neuvedete vzdaleny adresar, pripoji se vzdy domovsky adresar (neplati pro uzivatele root).";

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
	echo "Error: Nejprve je nutne zapsat seznam serveru do souboru ${DATFILE}";
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
