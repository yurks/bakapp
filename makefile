install:
	chmod +x bakapp.sh bakme.sh bakmejob.sh mailgen.sh mailsend.sh
	curl https://raw.githubusercontent.com/PHPMailer/PHPMailer/v5.2.23/class.phpmailer.php > class.phpmailer.php
