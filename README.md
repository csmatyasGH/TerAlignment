# Salesforce App

## Dev, Build and Test

## Resources

## Description of Files and Directories

## Issues

Leirom ide hogy a faszba csinaltam ezt
Csinatam 1 Bitbucket Repo-t.  uress volt semmibranck  semmi. egy csomo idot  elbaszyam  hogy megertesem incs  branch amit nem adok hozza valamit

INIT-alizaltam a local REPOT a VSC  UI-bol.  

utana: git remote add origin https://csmatyasBBK@bitbucket.org/csmatyasBBK/playgroundrepo.git              SZOVAL UGY TUNIK SEMMI CLONE NEM VOLT

hozzaadtam a terminal-bol:  git add manifest/package.xml

ezutan commit-oltam es utana push-oltam a remote ba.  Ekkor jelent meg a Branch es az elso commit a remote-ba
ezutan a package.xml alapjan retrieveltem a prod  solution es commitoltam majd push oltam

ezutan csialtam egy lokalis  branch et  de nem latom a terminal historiba  a command-ot(szerintem az UI  on csinaltam) Oda retrieve-eltem a DEV org-bol a solution-t. Ezt majd commit-oltam es push-oltam. Ezzel lett egy uj Branch a Remote -on.  DE EZT  MINTHA EM LATNA PUBLIKUSNAK A VSC AZERT MERT Terminal bol push oltam:  git push https://csmatyasBBK@bitbucket.org/csmatyasBBK/playgroundrepo.git DEV_BRANCH_LOCAL 

Kb itt tartok most

Akarok csinalni 1 backup branchet ahova  betoltom a master (prod)  kodot
majd a DEV_BRACH_LOCAL  brnachet- pull requeste vel mergelem a master-be

Azt is akarom hogy hozzaadok valami  a remote  branch hez  es azt PULL ozom de nem szeretnem elbaszni a local-t. Nem akarok belefutni abba hogy  ne tudjak push olni  mert esetleg van valami a remote  ba ahonnan eloszor pull ozni kell es csak utana push.  ROHADJAK MEG KURVA NEHEZEN MEGY A FEJEMBE, MONDOM EN HOGY FOGYATEKOS VAGYOK EBBE A TEMABA 


23:52   valoban a local master  es a Local DEV  branch ek mast  kodot tartalmaznak. A master a prod  an Local a  DEV  org kodja.  amint checkout  olok egy branch  et a working folder kodja eszrevetlenul valtozik.  

23:58   NEM lehet push -olni  branch-ek kozott. A local XYZ  branch-bol csak a megfelelo REMOTE XYZ  branch-be tudom push olni a dolgokat.  Szerintem branch  ek kozott csak pull request ill/  merge  parancs-al tudok kodot mozgatni. 

2020.04.29.  DEV_BRANCH_LOCAL was merget to master (azt hiszem ez nem volt tokeletes. nem tiszta  hogy  a lokalis  DV  branch et  mergeltem a Remote Master  hez vagya mokalis master hez)  meg tudnam nezni ha atvaltk a lokal  master-re
DE EZ NEM MEGY. a Remote  Master  re se tudok innen valtani  

kozben csinaltam 1  uj lokalis branch  et ahoba uj kodot irtam.  A cel hogy  az AlignCheck methodust  kibovitsem es tudjam merni az opp  sync  statisztikat

Ha a 2 lokalis DEB_BRANCH kozott valtogatok szepen latom hogy mas a kod. EDDIG JO.  



