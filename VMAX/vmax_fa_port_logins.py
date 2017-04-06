#!/usr/bin/python

import xml.etree.ElementTree as ET
import sys
import os


#==== CLASSES ======================================

class FAPort(object):
    FAName=""
    portNum=""
    portConnStatus=""
    portUsedAddressCount=0
    portActiveLogins=""
    portLoginHistory=""
    
    
    def __init__(self,faname,portNum,connStatus):
        self.FAName=faname
        self.portNum=portNum
        self.portConnStatus=connStatus
    
    def __str__(self):
        return(self.FAName+':'+self.portNum)
        
        
    
class FA(object):
    FAName=""
   
    def __init__(self,fa):
        self.FAName=fa.replace('FA-','')
        self.FAPorts={}
        
    def __str__(self):
        return(self.FAName.rjust(3))
    
    def addPort(self,portNum,connStatus):
        port=FAPort(self.FAName,portNum,connStatus)
        self.FAPorts[portNum]=port
    
    def getPortConnStatus(self,portNum):
        if portNum in self.FAPorts.keys():
            return(self.FAPorts[portNum].portConnStatus)
            
    def setPortUsedAddrCount(self,portNum,usedAddrCount):   
        if portNum in self.FAPorts.keys():
            self.FAPorts[portNum].portUsedAddressCount=usedAddrCount
    
    def getPortUsedAddrCount(self,portNum):
        if portNum in self.FAPorts.keys():
            return(self.FAPorts[portNum].portUsedAddressCount)
    
    def addActivePortLogin(self,portNum,login):
        if portNum in self.FAPorts.keys():
            self.FAPorts[portNum].portActiveLogins+=login + " "
    
    def getActivePortLogins(self,portNum):
        if portNum in self.FAPorts.keys():
            return(self.FAPorts[portNum].portActiveLogins)
    
    def addHistoricalPortLogin(self,portNum,login):
        if portNum in self.FAPorts.keys():
            self.FAPorts[portNum].portLoginHistory+=login + "(no_login) "
    
    def getHistoricalPortLogins(self,portNum):
        if portNum in self.FAPorts.keys():
            return(self.FAPorts[portNum].portLoginHistory)
    
    def getPortNums( self ):
        return self.FAPorts.keys() 
 
    def getFAUsedAddr( self ):
        usedFAAddr=0
        for portNum in self.FAPorts.keys():
            usedFAAddr+=self.FAPorts[portNum].portUsedAddressCount
        return( usedFAAddr )

    
#=== FUNCTIONS ===============================================

def discoverFAPorts(arrayID, FAs):

    portStatusTags={'0':'port0_status','1':'port1_status','2':'port2_status','3':'port3_status'}
    portConnTags={'0':'port0_conn_status','1':'port1_conn_status','2':'port2_conn_status','3':'port3_conn_status'}
    portConnStatuses={"Yes": "Yes", "N/A": "No"}
    
    try:
        symCfgFAPortCmd="export SYMCLI_OUTPUT_MODE=XML;" + SYMCLI_PATH + "symcfg -SID " + arrayID + " list -fa all -port"
        #DEBUG symCfgFAPortCmd="cat symcfg_fa_port.xml"
        symCfgFAPortXmlOut=os.popen(symCfgFAPortCmd).read()
    except:
        print("Command failed: " + symCfgFAPortCmd )
        sys.exit(1)

    try:
        xmlTree=ET.fromstring(symCfgFAPortXmlOut)
    except:
        sys.exit(1)

    try:
        symArray=xmlTree.find('Symmetrix')
    except:
        print("XML parsing error: couldn't find Symmetrix tag" )
        sys.exit(1)

    try:
        arrayID=symArray.find('Symm_Info').find('symid').text
    except:
        print("Command failed: " + symCfgFAPortCmd )
        sys.exit(1)
        
    for dir in symArray.findall('Director'):
        FAName=dir.find('Dir_Info').find('id').text
        newFA=FA(FAName)
        FAs[newFA.FAName]=newFA
      
        for portNum in portStatusTags.keys():
            portStatus=dir.find('Dir_Info').find(portStatusTags[portNum]).text
            portConnStatus=portConnStatuses[dir.find('Dir_Info').find(portConnTags[portNum]).text]
            
            if portStatus == "ON":
                newFA.addPort(portNum,portConnStatus)
    return(arrayID)           
                
def getUsedAddressCount(arrayID,FAs):

    try:
        symCfgCmd="export SYMCLI_OUTPUT_MODE=XML;" + SYMCLI_PATH + "symcfg -SID " + arrayID + " list -address -dir all"
        #DEBUG symCfgCmd="cat symcfg_addresses.xml"
        symCfgXmlOut=os.popen(symCfgCmd).read()  
    except:
        print("Command failed: " + symCfgCmd )
        sys.exit(1)

    xmlTree=ET.fromstring(symCfgXmlOut)
    symArray=xmlTree.find('Symmetrix')

    for dir in symArray.findall('Director'):
        FAName=dir.find('Dir_Info').find('id').text.replace('FA-','')
        portNum=dir.find('Dir_Info').find('port').text
        mappedDevsInclMetaMember=dir.find('Total').find('mapped_devs_w_metamember').text
        FAs[FAName].setPortUsedAddrCount(portNum, int(mappedDevsInclMetaMember))

       
def getPortLogins(arrayID,FAs):

    try:
        symAccessCmd="export SYMCLI_OUTPUT_MODE=XML;" + SYMCLI_PATH + "symaccess -SID " + arrayID + " list logins"
        #DEBUG symAccessCmd="cat symaccess_list_logins.xml"
    
        symAccessXmlOut=os.popen(symAccessCmd).read()
    except:
        print("Command failed: " + symCfgCmd )
        sys.exit(1)
        
    xmlTree=ET.fromstring(symAccessXmlOut)
    symArray=xmlTree.find('Symmetrix')

    for loginRecord in symArray.findall('Devmask_Login_Record'):
        FAName=loginRecord.find('director').text.replace('FA-','')
        portNum=loginRecord.find('port').text
      
        for login in loginRecord.findall('Login'):
            originatorPortWWN=login.find('originator_port_wwn').text
            aWWNN=login.find('awwn_node_name').text
            aWWPN=login.find('awwn_port_name').text
            loggedIn=login.find('logged_in').text
        
            if aWWNN == "NULL":
                initiator=originatorPortWWN
            else:
                initiator=aWWNN + "/" + aWWPN
        
            if loggedIn == "Yes":
                FAs[FAName].addActivePortLogin(portNum,initiator)
            else:
                FAs[FAName].addHistoricalPortLogin(portNum,initiator)
        

def printFAReport(arrayID,FAs):
    print("Array ID: " + arrayID + "\n")

    print( " FA:Port Connected UsedAddr AvailAddr Logins\n  ")

    for FA in sorted( FAs.keys(),key=lambda fa: fa.zfill(3)):
        portLine=""
        for portNum in sorted(FAs[FA].getPortNums()):
            portLine =FA.rjust(3) + ':' + portNum.ljust(5)
            portLine+=FAs[FA].getPortConnStatus(portNum).ljust(9) + " "
            portLine+=str(FAs[FA].getPortUsedAddrCount(portNum)).rjust(8) + " "
            portLine+=str(MAX_ADDRESSES_PER_FA-FAs[FA].getFAUsedAddr()).rjust(9) + " "
            portLine+=FAs[FA].getActivePortLogins(portNum) + " <> "
            portLine+=FAs[FA].getHistoricalPortLogins(portNum)
            print portLine
        print
        
  
#==== MAIN =========================================

FAs={}

MAX_ADDRESSES_PER_FA=4096
arrayID=""
SYMCLI_PATH=""


for arg in sys.argv:
    if arg == "-sid":
        arrayID="TBD"
    elif arrayID == "TBD":
        arrayID=arg
    elif arg == "-symcli_path":
        SYMCLI_PATH="TBD"
    elif SYMCLI_PATH == "TBD":
        SYMCLI_PATH=arg + '/'
    
if arrayID == "" or arrayID == "TBD" or SYMCLI_PATH == "TBD":    
    sys.stderr.write("Usage: vmax_fa_port_logins.py -sid <arrayID> [-symcli_path <path>]\n")
    sys.exit(1)
    

# Collect port login data
arrayID=discoverFAPorts(arrayID,FAs)
getUsedAddressCount(arrayID,FAs)
getPortLogins(arrayID,FAs)

# Print Report
printFAReport(arrayID,FAs)
 
