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

class expectError(Exception):
    TIMEOUT = "Connection Timeout"
    REJECT  = "Connection Rejected"
    LOGIN   = "Login incorrect"
    REBOOT  = "%s Not restarted after %d sec"
    UNKNOWN_NAME = "Name or service not known: %s"
    PERMISSION_DENIED = "Permission denied, check if password is correct"
    HOST_KEY = "Host key verification failed"

    def _get_message(self): return self._message
    def _set_message(self,message): self._message=message
    message = property(_get_message,_set_message)

class expect_generic:
    def __init__(self,tool,toaccess,logfile):
        self.logger=logging.FileHandler(logfile)
        self.logger.write = _write
        self.logger.flush = _doNothing

        self.tool=tool
        self.toaccess=toaccess

        self.user=""
        self.addr=""
        self.ip=""
        
        logging.info("Spawn %s %s" % (tool,toaccess))
        self.p = pexpect.spawn("%s %s" % (tool,toaccess),logfile=self.logger)
        time.sleep(2)

    def expect(self,expected):
        logging.debug("expect: START")
        #time.sleep(1)
        expected.extend([pexpect.EOF,pexpect.TIMEOUT])
        logging.debug("expect: input expected = "+str(expected))
        i=self.p.expect(expected)
        logging.debug("expect: received index "+str(i))
        logging.debug("expect: received buffer "+repr(self.p.buffer))
        if i==len(expected)-1:
            logging.error("### ERROR ### Connection timeout")
            print "### ERROR ### Connection timeout"
            logging.debug("expect: exit 1")
            raise expectError(expectError.TIMEOUT)

        elif i==len(expected)-2:
            logging.error("### ERROR ### Connection rejected")
            print "### ERROR ### Connection rejected"
            logging.debug("expect: exit 1")
            raise expectError(expectError.REJECT)

        else:
            if self.p.buffer.strip() == '':
                logging.debug("expect: return"+str(i))
                return i
            else:
                return self.expect(expected)

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

            #self.p.sendline(cmd)
            self.sendline(cmd)

            logging.debug("call expect")
            if len(self.prompt+' '+cmd)>79:
                val=len(self.prompt+' '+cmd) // 80
                cmd2=(self.prompt+' '+cmd)[val*80+1:]
                i=self.expect([cmd2+self.newline+self.prompt,cmd2+self.newline+"(.*)"+self.newline+self.prompt])
            else:
                i=self.expect([cmd+self.newline+self.prompt,cmd+self.newline+"(.*)"+self.newline+self.prompt])
            res=""
            if i==1:
                res=self.p.match.group(1)
                if '\r'+self.newline in res: res=res.replace('\r'+self.newline,'').replace(cmd,'').strip()
                elif self.newline in res: res=res.replace(self.newline,'').replace(cmd,'').strip()
                logging.debug("expect result: "+str(res))

            A_cmds[idx]['response']=res

            logging.debug("send 'echo $?' to get command return code")
            #self.p.sendline("echo $?")
            self.sendline("echo $?")
            i=self.expect(["echo \$\?"+self.newline+"([0-9]*)"+self.newline+self.prompt])
            rc=self.p.match.group(1).lstrip().rstrip()
            logging.debug("command return code: "+str(rc))
            A_cmds[idx]['rc']=rc

            print "command: "+cmd+"\nresponse: "+res+"\nrc: "+rc
            logging.info("   => rc: %s" % rc)
            logging.info("   => response: %s" % res)
    
        time.sleep(1)

        return A_cmds

    def get_param(self):
        A_cmds=self.exec_commands(["pwd","whoami","uname -n","ifconfig eth0 | grep 'inet addr' | sed 's/\s\+/ /g' | cut -d: -f2 | cut -d' ' -f1"])
        
        for cmd in A_cmds:
            if "whoami" in cmd['command'] and cmd['rc']=='0':
                self.user=cmd['response']
            if "uname" in cmd['command'] and cmd['rc']=='0':
                self.addr=cmd['response']
            if "ifconfig" in cmd['command'] and cmd['rc']=='0':
                self.ip=cmd['response']


    def reboot(self,ip=""):
        if ip=="": self.get_param()

        #import ping, socket
        logging.info('Reboot')
        #self.p.sendline('reboot')
        self.sendline('reboot')

        time.sleep(10)

        #polling if remote is restarted for 60sec
        import subprocess
        timeout=120
        restarted=False
        start=time.time()
        while time.time()-start < timeout:
            ping = subprocess.Popen(["ping", "-c", "1", self.ip], 
                                    stdout = subprocess.PIPE,
                                    stderr = subprocess.PIPE
                                    )
            out, error = ping.communicate()
            if '1 packets transmitted, 1 received' in out:
                logging.info("%s restarted after %d sec" % (self.toaccess,int(time.time()-start)))
                print "%s restarted after %d sec" % (self.toaccess,int(time.time()-start))
                restarted=True
                break
  
            time.sleep(1)

        if not  restarted:
            logging.error("### ERROR ### %s Not restarted after %d sec" % (self.toaccess,timeout))
            print "### ERROR ### %s Not restarted after %d sec" % (self.toaccess,timeout)
            logging.debug("reboot: exit 1")
            raise expectError(expectError.REBOOT % (self.toaccess, timeout))


        time.sleep(5)
        
    def sendline(self,string=""):
        for s in string:
            self.p.send(s)
            time.sleep(0.001)
        self.p.sendline('')
            
        
        
class expect_serial(expect_generic):

    def connect(self,args):
        self.expect(["Connected to %s console .*" % self.device,"ser2net port .*"])
        logging.info(' => Done')
        self.p.setwinsize(1000,1000)
        
        time.sleep(1)

        logging.debug("Send \r, expect 'login:' or prompt")
        #self.p.sendline("\r")
        self.sendline("")
        if self.expect(["login: ",self.prompt]) == 0:
            logging.debug(" => login: received")
            logging.info('Need login info')

            logging.debug("Send login(%s), expect 'Password:' or prompt" % self.login)
            #self.p.sendline(self.login)
            self.sendline(self.login)
            if self.expect(["Password: ",self.prompt]) == 0:
                logging.debug(" => 'Password:' received")
                logging.debug("Send password, expect 'Login incorrect' or prompt")
                #self.p.sendline(self.passwd)
                self.sendline(self.passwd)
                if self.expect(["Login incorrect",self.prompt])==0:
                    logging.error("### ERROR ### Login incorrect")
                    print "### ERROR ### Login incorrect"
                    raise expectError(expectError.LOGIN)
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

        #self.p.sendline("\r")
        self.sendline("")
        res = self.expect([self.newline+"# ",self.newline+"(.*)# "])
        if res == 1:
            elems=self.p.match.group(1).split(self.newline)
            self.prompt=elems[len(elems)-1]+"# "

    def disconnect(self):
        logging.info('Exit')
        #self.p.sendline("exit")
        self.sendline("exit")
        logging.debug("expect 'login:' before exit with success ")
        i=self.expect(["login: "])

        time.sleep(1)

        logging.info(' => Done')

class expect_conmux(expect_serial):
    def __init__(self,mandatory,logfile):
        self.device=mandatory[0]
        expect_generic.__init__(self,'conmux-console',self.device,logfile)

        self.user_passwd=mandatory[1].split(":")
        self.login = self.user_passwd[0]
        self.passwd= ""
        if len(self.user_passwd)==2: 
            self.passwd=self.user_passwd[1]

        self.newline='\r\r\n'
        self.prompt='#'



class expect_ser2net(expect_serial):
    def __init__(self,mandatory,logfile):
        self.device="localhost "+str(mandatory[0])
        expect_generic.__init__(self,'telnet',self.device,logfile)

        self.user_passwd=mandatory[1].split(":")
        self.login = self.user_passwd[0]
        self.passwd= ""
        if len(self.user_passwd)==2: 
            self.passwd=self.user_passwd[1]

        self.newline='\r\n'
        self.prompt='#'



class expect_ssh(expect_generic):
    def __init__(self,mandatory,logfile):
        self.addr=mandatory[0]
        self.passwd=mandatory[1]
        expect_generic.__init__(self,'ssh',self.addr,logfile)
        self.newline='\r\n'
        self.prompt='#'

    def connect(self,args):
        self.p.setwinsize(1000,1000)
        time.sleep(1)
        i = self.expect(["ssh: Could not resolve hostname (.*): Name or service not known",
                  "Are you sure you want to continue connecting \(yes/no\)\?","password:", "# "])
        if i == 0:
            logging.error("### ERROR ### Name or service not known: %s" % self.p.match.group(1))
            print "### ERROR ### Name or service not known: %s" % self.p.match.group(1)
            raise expectError(expectError.UNKNOWN_NAME % self.p.match.group(1))

        elif i == 1:
            #self.p.sendline("yes")
            self.sendline("yes")
            j = self.expect(["Host key verification failed.","# "])
            if j == 0:
                logging.error("### ERROR ### Host key verification failed")
                print "### ERROR ### Host key verification failed"
                sys.exit(1)
            
            elif j == 1:
                logging.info(' => Connection Done')
                logging.debug(" => prompt received")
                logging.debug(" => wait for commands")
        elif i == 2:
            while True:
                if self.passwd: 
                    #self.p.sendline(self.passwd)
                    self.sendline(self.passwd)
                else:        
                    #self.p.sendline("")
                    self.sendline("")

                j = self.expect(["Permission denied","password:","# "])
                if j==0:
                    logging.error("### ERROR ### Permission denied, check if password is correct")
                    print "### ERROR ### Permission denied, check if password is correct"
                    raise expectError(expectError.PERMISSION_DENIED)
                elif j==1:
                    continue
                elif j==2:
                    logging.info(' => Connection Done')
                    logging.debug(" => prompt received")
                    logging.debug(" => wait for commands")
                    break
            

        elif i == 3:
            logging.info(' => Connection Done')
            logging.debug(" => prompt received")
            logging.debug(" => wait for commands")

        #self.p.sendline("\r")
        self.sendline("")
        res = self.expect([self.newline+"# ",self.newline+"(.*)# "])
        if res == 1:
            elems=self.p.match.group(1).split(self.newline)
            self.prompt=elems[len(elems)-1]+"# "
      

    def disconnect(self):
        logging.info('Exit')
        #self.p.sendline("exit")
        self.sendline("exit")
        logging.debug("expect 'Connection to <addr> closed.' before exit with success ")
        i=self.expect(["Connection to (.*) closed."])
        logging.info(' => Done')

class expect_scp(expect_generic):
    def __init__(self,mandatory,logfile):
        self.src=mandatory[0]
        self.dst=mandatory[1]

        if ':' in self.src: self.src_addr=self.src.split(':')[0]
        if ':' in self.dst: self.dst_addr=self.dst.split(':')[0]
        self.src_passwd=mandatory[2]
        self.dst_passwd=mandatory[3]

        expect_generic.__init__(self,'scp',"%s %s" % (self.src,self.dst),logfile)
        self.newline='\r\n'
        self.prompt='#'

    def connect(self,args):
        time.sleep(1)
        i = self.expect(["Name or service not known",
                  "Are you sure you want to continue connecting \(yes/no\)\?",
                  "%s(.*)'s password:" % self.newline,
                  "# ", '(.*)'])
        if i == 0:
            logging.error("### ERROR ### Name or service not known: %s" % self.p.match.group(1))
            print "### ERROR ### Name or service not known: %s" % self.p.match.group(1)
            raise expectError(expectError.UNKNOWN_NAME % self.p.match.group(1))


        elif i == 1:
            #self.p.sendline("yes")
            self.sendline("yes")
            j = self.expect(["Host key verification failed.","# "])
            if j == 0:
                logging.error("### ERROR ### Host key verification failed")
                print "### ERROR ### Host key verification failed"
                raise expectError(expectError.HOST_KEY)
            
            elif j == 1:
                logging.info(' => Connection Done')
                logging.debug(" => prompt received")
                logging.debug(" => wait for commands")

        elif i == 2:
            if self.src_addr in self.p.group(1):
                #self.p.sendline(self.src_passwd)
                self.sendline(self.src_passwd)
            elif self.dst_addr in self.p.group(1):
                #self.p.sendline(self.dst_passwd)
                self.sendline(self.dst_passwd)

            while True:
                if self.src_addr in self.p.group(1): passwd = self.src_passwd
                elif self.dst_addr in self.p.group(1): passwd = self.dst_passwd

                if passwd: 
                    #self.p.sendline(passwd)
                    self.sendline(passwd)
                else:      
                    #self.p.sendline("")
                    self.sendline("")

                j = self.expect(["Permission denied","%s(.*)'s password:","# "])
                if j==0:
                    logging.error("### ERROR ### Permission denied, check if password is correct")
                    print "### ERROR ### Permission denied, check if password is correct"
                    raise expectError(expectError.PERMISSION_DENIED)

                elif j==1:
                    continue
                elif j==2:
                    logging.info(' => Connection Done')
                    logging.debug(" => prompt received")
                    logging.debug(" => wait for commands")
                    break


        elif i == 3:
            logging.info(' => Connection Done')
            logging.debug(" => prompt received")
            logging.debug(" => wait for commands")

        time.sleep(1)
        self.p.setwinsize(1000,1000)

        #self.p.sendline("\r")
        self.sendline("")
        res = self.expect([self.newline+"#",self.newline+"(.*)# "])
        if res == 1:
            elems=self.p.match.group(1).split(self.newline)
            self.prompt=elems[len(elems)-1]+"#"


    def disconnect(self):
        pass

def expect_exec_cmd(tool,mandatory_args,args):
    if args.verbosity: verbosity_level=logging.DEBUG
    else:              verbosity_level=logging.INFO
    if not args.keeplog and os.path.isfile(args.logfile): 
        os.remove(args.logfile)
    logging.basicConfig(filename=args.logfile,filemode='a',level=verbosity_level,format='%(filename)s - %(levelname)s - %(message)s')

    try:
        t = tool(mandatory_args,args.logfile)
        t.connect(args)

        if args.reboot:
            t.reboot()

        elif args.commands:
            commands_list=create_commands_list(args.commands)
            A_cmds=t.exec_commands(commands_list)

            t.disconnect()

            return A_cmds

    except:
        sys.exit(1)

def conmux_exec_cmd(args):
    mandatory_args=[args.device,args.user_passwd]
    return expect_exec_cmd(expect_conmux,mandatory_args,args)

def ser2net_exec_cmd(args):
    mandatory_args=[args.port,args.user_passwd]
    return expect_exec_cmd(expect_ser2net,mandatory_args,args)

def ssh_exec_cmd(args):
    mandatory_args=[args.addr,args.password]
    return expect_exec_cmd(expect_ssh,mandatory_args,args)

def scp_exec_cmd(args):
    mandatory_args=[args.src,args.dst,args.src_password,args.dst_password]
    return expect_exec_cmd(expect_scp,mandatory_args,args)

def main():
    #usage = "Usage: %prog [-v<N>][-l logfile][-u user[:password]] device_name CMD [CMD ...]"
    description = "Type expect_exec_cmd.py <tool_name> -h|--help for more help on <tool_name>"

    #parser = argparse.ArgumentParser(usage=usage, description=description)
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("-l", "--logfile",   action="store",      dest='logfile', default="expect_exec_cmd.log", 
                       help="logfile to use, default is conmux_cmd.log")
    parser.add_argument("--keeplog",   action="store_true",      dest='keeplog', default=False, 
                       help="keep logfile if already exist, remove it if not")
    parser.add_argument("-v", "--verbosity", action="store_true", dest='verbosity', default=False, 
                       help="verbosity level, default=0")
    parser.add_argument("--version",         action="version", version='expect_exec_cmd.py version: 1.0', 
                       help="print version")
    parser.add_argument("--reboot",          action="store_true", dest='reboot', default=False,
                       help="reboot host")

    subparsers=parser.add_subparsers(help="tool_name used for connection")
    parser_conmux=subparsers.add_parser('conmux-console', help="connection via conmux-console.")
    parser_conmux.add_argument('device',  metavar='device', 
                        help="device_name to connect")
    parser_conmux.add_argument('-u', "--user",      action="store",      dest='user_passwd', default="root", 
                        help="user[:password] for connection, default user is root")
    parser_conmux.add_argument('commands', metavar='CMD', nargs='+',
                       help="command(s) (can be file name) to be executed")
    parser_conmux.set_defaults(func=conmux_exec_cmd)

    parser_ser2net=subparsers.add_parser('telnet', help="connection via telnet.")
    parser_ser2net.add_argument('port',  metavar='port', 
                        help="port number used to connect")
    parser_ser2net.add_argument('-u', "--user",      action="store",      dest='user_passwd', default="root", 
                        help="user[:password] for connection, default user is root")
    parser_ser2net.add_argument('commands', metavar='CMD', nargs='+',
                       help="command(s) (can be file name) to be executed")
    parser_ser2net.set_defaults(func=ser2net_exec_cmd)

    parser_ssh=subparsers.add_parser('ssh', help="connection via ssh.")
    parser_ssh.add_argument('addr',  metavar='addr', 
                        help="addr to connect")
    parser_ssh.add_argument('-p', "--password",      action="store",      dest='password', 
                        help="password used to connect")
    parser_ssh.add_argument('commands', metavar='CMD', nargs='+',
                       help="command(s) (can be file name) to be executed")
    parser_ssh.set_defaults(func=ssh_exec_cmd)

    parser_scp=subparsers.add_parser('scp', help="copy file via ssh.")
    parser_scp.add_argument('-s', "--src-password",      action="store",      dest='src_password', 
                        help="source password used to connect source")
    parser_scp.add_argument('-d', "--dst-password",      action="store",      dest='dst_password', 
                        help="destination password used to connect destination")
    parser_scp.add_argument('src', metavar='SRC',
                       help="local source file to be copied")
    parser_scp.add_argument('dst', metavar='DST',
                       help="remote destination filename and path")
    parser_scp.set_defaults(func=scp_exec_cmd)

    args=parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()



