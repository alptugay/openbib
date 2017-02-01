#!/bin/bash

echo "Abgleich Philfak intern nach ISBN13"

/opt/openbib/bin/bestandsabgleich.pl --selector=ISBN13 --location=DE-38-306 --location=DE-38-311 --location=DE-38-312 --location=DE-38-313 --location=DE-38-323 --location=DE-38-325 --location=DE-38-401 --location=DE-38-404 --location=DE-38-405 --location=DE-38-406 --location=DE-38-407 --location=DE-38-408 --location=DE-38-409 --location=DE-38-410 --location=DE-38-411 --location=DE-38-412 --location=DE-38-413 --location=DE-38-414 --location=DE-38-416 --location=DE-38-418 --location=DE-38-419 --location=DE-38-420 --location=DE-38-422 --location=DE-38-423 --location=DE-38-425 --location=DE-38-426 --location=DE-38-427 --location=DE-38-428 --location=DE-38-429 --location=DE-38-430 --location=DE-38-431 --location=DE-38-432 --location=DE-38-434 --location=DE-38-437 --location=DE-38-438 --location=DE-38-444 --location=DE-38-445 --location=DE-38-448 --location=DE-38-450 --location=DE-38-459reorg --location=DE-38-460 --location=DE-38-461 --location=DE-38-462 --location=DE-38-464 --location=DE-38-466 --location=DE-38-467 --location=DE-38-468 --location=DE-38-622 --location=DE-38-623 --filename=abgleich_philfak_by_isbn.csv

#echo "Abgleich Philfak intern nach BibKey"

#/opt/openbib/bin/bestandsabgleich.pl --selector=BibKey --location=DE-38-306 --location=DE-38-311 --location=DE-38-312 --location=DE-38-313 --location=DE-38-323 --location=DE-38-325 --location=DE-38-401 --location=DE-38-404 --location=DE-38-405 --location=DE-38-406 --location=DE-38-407 --location=DE-38-408 --location=DE-38-409 --location=DE-38-410 --location=DE-38-411 --location=DE-38-412 --location=DE-38-413 --location=DE-38-414 --location=DE-38-416 --location=DE-38-418 --location=DE-38-419 --location=DE-38-420 --location=DE-38-422 --location=DE-38-423 --location=DE-38-425 --location=DE-38-426 --location=DE-38-427 --location=DE-38-428 --location=DE-38-429 --location=DE-38-430 --location=DE-38-431 --location=DE-38-432 --location=DE-38-434 --location=DE-38-437 --location=DE-38-438 --location=DE-38-444 --location=DE-38-445 --location=DE-38-448 --location=DE-38-450 --location=DE-38-459reorg --location=DE-38-460 --location=DE-38-461 --location=DE-38-462 --location=DE-38-464 --location=DE-38-466 --location=DE-38-467 --location=DE-38-468 --location=DE-38-622 --location=DE-38-623 --filename=abgleich_philfak_by_bibkey.csv

echo "Abgleich USB und Philfak nach ISBN13"

/opt/openbib/bin/bestandsabgleich.pl --selector=ISBN13 --location=DE-38 --location=DE-38-HWA --location=DE-38-306 --location=DE-38-311 --location=DE-38-312 --location=DE-38-313 --location=DE-38-323 --location=DE-38-325 --location=DE-38-401 --location=DE-38-404 --location=DE-38-405 --location=DE-38-406 --location=DE-38-407 --location=DE-38-408 --location=DE-38-409 --location=DE-38-410 --location=DE-38-411 --location=DE-38-412 --location=DE-38-413 --location=DE-38-414 --location=DE-38-416 --location=DE-38-418 --location=DE-38-419 --location=DE-38-420 --location=DE-38-422 --location=DE-38-423 --location=DE-38-425 --location=DE-38-426 --location=DE-38-427 --location=DE-38-428 --location=DE-38-429 --location=DE-38-430 --location=DE-38-431 --location=DE-38-432 --location=DE-38-434 --location=DE-38-437 --location=DE-38-438 --location=DE-38-444 --location=DE-38-445 --location=DE-38-448 --location=DE-38-450 --location=DE-38-459reorg --location=DE-38-460 --location=DE-38-461 --location=DE-38-462 --location=DE-38-464 --location=DE-38-466 --location=DE-38-467 --location=DE-38-468 --location=DE-38-622 --location=DE-38-623 --filename=abgleich_usb_philfak_by_isbn.csv

#echo "Abgleich USB und Philfak nach BibKey"

#/opt/openbib/bin/bestandsabgleich.pl --selector=BibKey --location=DE-38 --location=DE-38-HWA --location=DE-38-306 --location=DE-38-311 --location=DE-38-312 --location=DE-38-313 --location=DE-38-323 --location=DE-38-325 --location=DE-38-401 --location=DE-38-404 --location=DE-38-405 --location=DE-38-406 --location=DE-38-407 --location=DE-38-408 --location=DE-38-409 --location=DE-38-410 --location=DE-38-411 --location=DE-38-412 --location=DE-38-413 --location=DE-38-414 --location=DE-38-416 --location=DE-38-418 --location=DE-38-419 --location=DE-38-420 --location=DE-38-422 --location=DE-38-423 --location=DE-38-425 --location=DE-38-426 --location=DE-38-427 --location=DE-38-428 --location=DE-38-429 --location=DE-38-430 --location=DE-38-431 --location=DE-38-432 --location=DE-38-434 --location=DE-38-437 --location=DE-38-438 --location=DE-38-444 --location=DE-38-445 --location=DE-38-448 --location=DE-38-450 --location=DE-38-459reorg --location=DE-38-460 --location=DE-38-461 --location=DE-38-462 --location=DE-38-464 --location=DE-38-466 --location=DE-38-467 --location=DE-38-468 --location=DE-38-622 --location=DE-38-623 --filename=abgleich_usb_philfak_by_bibkey.csv
