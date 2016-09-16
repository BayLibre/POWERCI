#!/usr/bin/python
import pexpect
import time
import sys, os, re
import argparse
import logging

#import pdb

def expect(p,expected):
    time.sleep(2)
    expected.extend([pexpect.EOF,pexpect.TIMEOUT])
    i=p.expect(expected)
    if i==len(expected)-1:
        logging.error("### ERROR ### Connection timeout")
        print "### ERROR ### Connection timeout"
        sys.exit(1)
    elif i==len(expected)-2:
        logging.error("### ERROR ### Connection rejected")
        print "### ERROR ### Connection rejected"
        sys.exit(1)
    else:
        return i

def get_commands(commands):
    A_cmds=[]
    for c in commands:
        if os.path.isfile(c):
            A_lines=[]
            for l in open(c,'r'):
                line=l.split('#')[0].lstrip().rstrip()
                if line=="": continue
                A_lines.append(line)
            A_cmds.extend(get_commands(A_lines))
        else:
            A_cmds.append(c)

    return A_cmds

def conmux_cmd(device,commands,user="root",logfile="conmux_cmd.log",verbosity=False):
    if verbosity: verbosity_level=logging.DEBUG
    else:         verbosity_level=logging.INFO
    logging.basicConfig(filename=logfile,filemode='a',level=verbosity_level,format='%(filename)s - %(levelname)s - %(message)s')

    logging.info('Connect to '+device)
    #p = pexpect.spawn("conmux-console %s" % device,logfile=open(logfile,'a'))
    p = pexpect.spawn("conmux-console %s" % device)
    expect(p,["Connected to %s console .*" % device])
    logging.info(' => Done')

    p.sendline("\r")
    if expect(p,["login: ","# "]) == 0:
        logging.info('Need login info')
        login=user.split(":")
        p.sendline(login[0])

        if expect(p,["Password: ","# "]) == 0:
            if len(login)==1: passwd=""
            else:             passwd=login[1]
            p.sendline(passwd)
            if expect(p,["Login incorrect","# "])==0:
                logging.error("### ERROR ### Login incorrect")
                print "### ERROR ### Login incorrect"
                sys.exit(1)
            else:
                logging.info(' => OK')
    
    #if commands is an existing file, it contains a list of commands
    #populate a list of dict
    A_cmds=[{'command':c,'response':None,'rc':0} for c in get_commands(commands)]
    logging.info('%d Command(s) found' % len(A_cmds))

    logging.info('Execute commands')
    #execute commands
    for idx in range(len(A_cmds)):
        cmd=A_cmds[idx]['command']
        logging.info("command: %s" % cmd)

        p.sendline(cmd)
        i=expect(p,["(.*)\r\r\n#","\r\r\n#"])
        res=""
        if i==0:
            res=p.match.group(1)
            if '\r\r\r\n' in res: res=res.replace('\r\r\r\n','').replace(cmd,'').strip()
            elif '\r\r\n' in res: res=res.replace('\r\r\n','').replace(cmd,'').strip()

        A_cmds[idx]['response']=res

        p.sendline("echo $?")
        i=expect(p,["echo \$\?\r\r\n([0-9]*)\r\r\n#"])
        rc=p.match.group(1).lstrip().rstrip()
        A_cmds[idx]['rc']=rc

        print "command: "+cmd+"\nresponse: "+res+"\nrc: "+rc
        logging.info("   => rc: %d" % rc)
        logging.info("   => response: %s" % res)

    logging.info('Exit')
    p.sendline("exit")
    i=expect(p,["login: "])
    logging.info(' => Done')
    return A_cmds


def main():
    #usage = "Usage: %prog [-v<N>][-l logfile][-u user[:password]] device_name CMD [CMD ...]"
    description = "execute commands on device via conmux-console"

    #parser = argparse.ArgumentParser(usage=usage, description=description)
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('device',  metavar='device', nargs=1, 
                        help="device_name to connect")
    parser.add_argument('commands', metavar='CMD', nargs='+',
                       help="command(s) (can be file name) to be executed")
    parser.add_argument('-u', "--user",      action="store",      dest='user', default="root", 
                        help="user[:password] for connection, default is root")
    parser.add_argument("-l", "--logfile",   action="store",      dest='logfile', default="conmux_cmd.log", 
                       help="logfile to use, default is conmux_cmd.log")
    parser.add_argument("-v", "--verbosity", action="store_true", dest='verbosity', default=False, 
                       help="verbosity level, default=0")
    parser.add_argument("--version",         action="version", version='Version v0.1', 
                       help="print version")

    args=parser.parse_args()

    #pdb.set_trace()
    conmux_cmd(args.device[0], args.commands, args.user, args.logfile, args.verbosity)



if __name__ == '__main__':
    main()



