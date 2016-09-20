#!/usr/bin/python
import pexpect
import time
import sys, os, re
import argparse
import logging

def _write(*args, **kwargs):
    content = args[0]
    if content in ['','\r','\n','\r\n','\r\r\n']:
        return
    for eol in ['\r\r\n','\r\n','\r','\n']:
        content = re.sub('\%s$' % eol,'',content)
    return logging.info(content)
def _doNothing(): pass


def create_commands_list(commands):
    logging.debug("get_commands: START")
    logging.debug("get_commands: input commands = "+str(commands))

    A_cmds=[]
    for c in commands:
        if os.path.isfile(c):
            A_lines=[]
            for l in open(c,'r'):
                line=l.split('#')[0].lstrip().rstrip()
                if line=="": continue
                A_lines.append(line)
            A_cmds.extend(create_commands_list(A_lines))
        else:
            A_cmds.append(c)

    logging.debug("get_commands: return "+str(A_cmds))
    return A_cmds

class expect_generic:
    def __init__(self,tool,toaccess,logfile):
        self.logger=logging.FileHandler(logfile)
        self.logger.write = _write
        self.logger.flush = _doNothing
        
        logging.info('Connect to '+toaccess)
        self.p = pexpect.spawn("%s %s" % (tool,toaccess),logfile=self.logger)


    def expect(self,expected):
        logging.debug("expect: START")
        logging.debug("expect: input expected = "+str(expected))
        time.sleep(2)
        expected.extend([pexpect.EOF,pexpect.TIMEOUT])
        i=self.p.expect(expected)
        if i==len(expected)-1:
            logging.error("### ERROR ### Connection timeout")
            print "### ERROR ### Connection timeout"
            logging.debug("expect: exit 1")
            sys.exit(1)
        elif i==len(expected)-2:
            logging.error("### ERROR ### Connection rejected")
            print "### ERROR ### Connection rejected"
            logging.debug("expect: exit 1")
            sys.exit(1)
        else:
            logging.debug("expect: return"+str(i))
            return i

    def connect(self):
        pass

    def disconnect(self):
        pass

    def exec_commands(self,commands):
        #if commands is an existing file, it contains a list of commands
        #populate a list of dict
        A_cmds=[{'command':c,'response':None,'rc':0} for c in commands]
        logging.info('%d Command(s) found' % len(A_cmds))

        logging.info('Execute commands')
        #execute commands
        for idx in range(len(A_cmds)):
            cmd=A_cmds[idx]['command']
            logging.info("command: %s" % cmd)

            self.p.sendline(cmd)
            logging.debug("call expect")
            if len(' '+cmd)>79:
                cmd1=(' '+cmd)[:79]
                cmd2=(' '+cmd)[80:]
                i=self.expect([cmd1+"\r"+self.newline+cmd2+self.newline+"#",cmd1+"\r"+self.newline+cmd2+self.newline+"(.*)"+self.newline+"#"])
            else:
                i=self.expect([cmd+self.newline+"#",cmd+self.newline+"(.*)"+self.newline+"#"])
            res=""
            if i==1:
                res=self.p.match.group(1)
                if '\r'+self.newline in res: res=res.replace('\r'+self.newline,'').replace(cmd,'').strip()
                elif self.newline in res: res=res.replace(self.newline,'').replace(cmd,'').strip()
                logging.debug("expect result: "+str(res))

            A_cmds[idx]['response']=res

            logging.debug("send 'echo $?' to get command return code")
            self.p.sendline("echo $?")
            i=self.expect(["echo \$\?"+self.newline+"([0-9]*)"+self.newline+"#"])
            rc=self.p.match.group(1).lstrip().rstrip()
            logging.debug("command return code: "+str(rc))
            A_cmds[idx]['rc']=rc

            print "command: "+cmd+"\nresponse: "+res+"\nrc: "+rc
            logging.info("   => rc: %s" % rc)
            logging.info("   => response: %s" % res)
    
        return A_cmds

class expect_conmux(expect_generic):
    def __init__(self,device,logfile):
        self.device=device
        expect_generic.__init__(self,'conmux-console',self.device,logfile)
        self.newline='\r\r\n'

    def connect(self,user_passwd="root"):
        login=user_passwd.split(":")

        self.expect(["Connected to %s console .*" % self.device])
        logging.info(' => Done')
        self.p.setwinsize(1000,1000)

        logging.debug("Send \r, expect 'login:' or prompt")
        self.p.sendline("\r")
        if self.expect(["login: ","# "]) == 0:
            logging.debug(" => login: received")
            logging.info('Need login info')

            logging.debug("Send login, expect 'Password:' or prompt")
            self.p.sendline(login[0])
            if self.expect(["Password: ","# "]) == 0:
                logging.debug(" => 'Password:' received")
                if len(login)==1: passwd=""
                else:             passwd=login[1]
                logging.debug("Send password, expect 'Login incorrect' or prompt")
                self.p.sendline(passwd)
                if self.expect(["Login incorrect","# "])==0:
                    logging.error("### ERROR ### Login incorrect")
                    print "### ERROR ### Login incorrect"
                    sys.exit(1)
                else:
                    logging.debug(" => prompt received")
                    logging.debug(" => wait for commands")
                    logging.info(' => OK')
            else:
                logging.debug(" => prompt received")
                logging.debug(" => wait for commands")

        else:
            logging.debug(" => prompt received")
            logging.debug(" => wait for commands")

        self.p.sendline("\r")
        res = self.expect(["# "])


    def disconnect(self):
        logging.info('Exit')
        self.p.sendline("exit")
        logging.debug("expect 'login:' before exit with success ")
        i=self.expect(["login: "])
        logging.info(' => Done')

class expect_ssh(expect_generic):
    def __init__(self,addr,logfile):
        self.addr=addr
        expect_generic.__init__(self,'ssh',self.addr,logfile)
        self.newline='\r\n'

    def connect(self):
        res = self.expect(["ssh: Could not resolve hostname (.*): Name or service not known",
                  "Are you sure you want to continue connecting (yes/no) ?",
                  "# "])
        if res == 0:
            logging.error("### ERROR ### Name or service not known: %s" % self.p.match.group(1))
            print "### ERROR ### Name or service not known: %s" % self.p.match.group(1)
            sys.exit(1)

        elif res == 1:
            self.p.sendline("yes")
            res = self.expect(["Host key verification failed.","# "])
            if res == 0:
                logging.error("### ERROR ### Host key verification failed")
                print "### ERROR ### Host key verification failed"
                sys.exit(1)
            
            elif res == 1:
                logging.info(' => Connection Done')
                logging.debug(" => prompt received")
                logging.debug(" => wait for commands")

        elif res == 2:
            logging.info(' => Connection Done')
            logging.debug(" => prompt received")
            logging.debug(" => wait for commands")

        self.p.setwinsize(1000,1000)

        self.p.sendline("\r")
        res = self.expect(["# "])


    def disconnect(self):
        logging.info('Exit')
        self.p.sendline("exit")
        logging.debug("expect 'Connection to <addr> closed.' before exit with success ")
        i=self.expect(["Connection to (.*) closed."])
        logging.info(' => Done')


def expect_exec_cmd(tool,mandatory_args,args):
    if args.verbosity: verbosity_level=logging.DEBUG
    else:              verbosity_level=logging.INFO
    logging.basicConfig(filename=args.logfile,filemode='a',level=verbosity_level,format='%(filename)s - %(levelname)s - %(message)s')

    commands_list=create_commands_list(args.commands)

    t = tool(mandatory_args[0],args.logfile)
    if mandatory_args[1]: t.connect(mandatory_args[1])
    else:                 t.connect()
    A_cmds=t.exec_commands(commands_list)
    t.disconnect()

    return A_cmds

def conmux_exec_cmd(args):
    mandatory_args=[args.device,args.user]
    return expect_exec_cmd(expect_conmux,mandatory_args,args)

def ssh_exec_cmd(args):
    mandatory_args=[args.addr,None]
    return expect_exec_cmd(expect_ssh,mandatory_args,args)

def main():
    #usage = "Usage: %prog [-v<N>][-l logfile][-u user[:password]] device_name CMD [CMD ...]"
    description = "execute commands on device via conmux-console"

    #parser = argparse.ArgumentParser(usage=usage, description=description)
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("-l", "--logfile",   action="store",      dest='logfile', default="conmux_cmd.log", 
                       help="logfile to use, default is conmux_cmd.log")
    parser.add_argument("-v", "--verbosity", action="store_true", dest='verbosity', default=False, 
                       help="verbosity level, default=0")
    parser.add_argument("--version",         action="version", version='Version v0.1', 
                       help="print version")

    subparsers=parser.add_subparsers(help="tool used for connection")
    parser_conmux=subparsers.add_parser('conmux-console', help="connection via conmux-console.")
    parser_conmux.add_argument('device',  metavar='device', 
                        help="device_name to connect")
    parser_conmux.add_argument('-u', "--user",      action="store",      dest='user', default="root", 
                        help="user[:password] for connection, default is root")
    parser_conmux.add_argument('commands', metavar='CMD', nargs='+',
                       help="command(s) (can be file name) to be executed")
    parser_conmux.set_defaults(func=conmux_exec_cmd)

    parser_ssh=subparsers.add_parser('ssh', help="connection via ssh.")
    parser_ssh.add_argument('addr',  metavar='addr', 
                        help="addr to connect")
    parser_ssh.add_argument('commands', metavar='CMD', nargs='+',
                       help="command(s) (can be file name) to be executed")
    parser_ssh.set_defaults(func=ssh_exec_cmd)


    args=parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()



