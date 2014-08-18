/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.oozie.service;

import org.apache.oozie.lock.LockToken;
import org.apache.oozie.util.*;
import org.apache.oozie.test.ZKXTestCase;

public class TestZKLocksService extends ZKXTestCase {
    private XLog log = XLog.getLog(getClass());

    @Override
    protected void setUp() throws Exception {
        super.setUp();
    }

    @Override
    protected void tearDown() throws Exception {
        super.tearDown();
    }

    public void testRegisterUnregister() throws Exception {
        assertEquals(0, ZKUtils.getUsers().size());
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            assertEquals(1, ZKUtils.getUsers().size());
            assertEquals(zkls, ZKUtils.getUsers().iterator().next());
            zkls.destroy();
            assertEquals(0, ZKUtils.getUsers().size());
        }
        finally {
            zkls.destroy();
        }
    }

    public abstract class Locker implements Runnable {
        protected String name;
        private String nameIndex;
        private StringBuffer sb;
        protected long timeout;
        protected ZKLocksService zkls;

        public Locker(String name, int nameIndex, long timeout, StringBuffer buffer, ZKLocksService zkls) {
            this.name = name;
            this.nameIndex = name + ":" + nameIndex;
            this.sb = buffer;
            this.timeout = timeout;
            this.zkls = zkls;
        }

        @Override
        public void run() {
            try {
                log.info("Getting lock [{0}]", nameIndex);
                LockToken token = getLock();
                if (token != null) {
                    log.info("Got lock [{0}]", nameIndex);
                    sb.append(nameIndex).append("-L ");
                    synchronized (this) {
                        wait();
                    }
                    sb.append(nameIndex).append("-U ");
                    token.release();
                    log.info("Release lock [{0}]", nameIndex);
                }
                else {
                    sb.append(nameIndex).append("-N ");
                    log.info("Did not get lock [{0}]", nameIndex);
                }
            }
            catch (Exception ex) {
                throw new RuntimeException(ex);
            }
        }

        public void finish() {
            synchronized (this) {
                notify();
            }
        }

        protected abstract ZKLocksService.ZKLockToken getLock() throws InterruptedException;
    }

    public class ReadLocker extends Locker {

        public ReadLocker(String name, int nameIndex, long timeout, StringBuffer buffer, ZKLocksService zkls) {
            super(name, nameIndex, timeout, buffer, zkls);
        }

        @Override
        protected ZKLocksService.ZKLockToken getLock() throws InterruptedException {
            return (ZKLocksService.ZKLockToken)zkls.getReadLock(name, timeout);
        }
    }

    public class WriteLocker extends Locker {

        public WriteLocker(String name, int nameIndex, long timeout, StringBuffer buffer, ZKLocksService zkls) {
            super(name, nameIndex, timeout, buffer, zkls);
        }

        @Override
        protected ZKLocksService.ZKLockToken getLock() throws InterruptedException {
            return (ZKLocksService.ZKLockToken)zkls.getWriteLock(name, timeout);
        }
    }

    public void testWaitWriteLockThreads() throws Exception {
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            _testWaitWriteLock(zkls, zkls);
        }
        finally {
            zkls.destroy();
        }
    }

    public void testWaitWriteLockOozies() throws Exception {
        // Simulate having two different Oozies by using two different ZKLocksServices instead of using the same one in two threads
        ZKLocksService zkls1 = new ZKLocksService();
        ZKLocksService zkls2 = new ZKLocksService();
        try {
            zkls1.init(Services.get());
            zkls2.init(Services.get());
            _testWaitWriteLock(zkls1, zkls2);
        }
        finally {
            zkls1.destroy();
            zkls2.destroy();
        }
    }

    public void _testWaitWriteLock(ZKLocksService zkls1, ZKLocksService zkls2) throws Exception {
        StringBuffer sb = new StringBuffer("");
        Locker l1 = new WriteLocker("a", 1, -1, sb, zkls1);
        Locker l2 = new WriteLocker("a", 2, -1, sb, zkls2);

        new Thread(l1).start();
        Thread.sleep(500);
        new Thread(l2).start();
        Thread.sleep(500);
        l1.finish();
        Thread.sleep(500);
        l2.finish();
        Thread.sleep(500);
        assertEquals("a:1-L a:1-U a:2-L a:2-U", sb.toString().trim());
    }

    public void testNoWaitWriteLockThreads() throws Exception {
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            _testNoWaitWriteLock(zkls, zkls);
        }
        finally {
            zkls.destroy();
        }
    }

    public void testNoWaitWriteLockOozies() throws Exception {
        // Simulate having two different Oozies by using two different ZKLocksServices instead of using the same one in two threads
        ZKLocksService zkls1 = new ZKLocksService();
        ZKLocksService zkls2 = new ZKLocksService();
        try {
            zkls1.init(Services.get());
            zkls2.init(Services.get());
            _testNoWaitWriteLock(zkls1, zkls2);
        }
        finally {
            zkls1.destroy();
            zkls2.destroy();
        }
    }

    public void _testNoWaitWriteLock(ZKLocksService zkls1, ZKLocksService zkls2) throws Exception {
        StringBuffer sb = new StringBuffer("");
        Locker l1 = new WriteLocker("a", 1, 0, sb, zkls1);
        Locker l2 = new WriteLocker("a", 2, 0, sb, zkls2);

        new Thread(l1).start();
        Thread.sleep(500);
        new Thread(l2).start();
        Thread.sleep(500);
        l1.finish();
        Thread.sleep(500);
        l2.finish();
        Thread.sleep(500);
        assertEquals("a:1-L a:2-N a:1-U", sb.toString().trim());
    }

    public void testTimeoutWaitingWriteLockThreads() throws Exception {
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            _testTimeoutWaitingWriteLock(zkls, zkls);
        }
        finally {
            zkls.destroy();
        }
    }

    public void testTimeoutWaitingWriteLockOozies() throws Exception {
        // Simulate having two different Oozies by using two different ZKLocksServices instead of using the same one in two threads
        ZKLocksService zkls1 = new ZKLocksService();
        ZKLocksService zkls2 = new ZKLocksService();
        try {
            zkls1.init(Services.get());
            zkls2.init(Services.get());
            _testTimeoutWaitingWriteLock(zkls1, zkls2);
        }
        finally {
            zkls1.destroy();
            zkls2.destroy();
        }
    }

    public void _testTimeoutWaitingWriteLock(ZKLocksService zkls1, ZKLocksService zkls2) throws Exception {
        StringBuffer sb = new StringBuffer("");
        Locker l1 = new WriteLocker("a", 1, 0, sb, zkls1);
        Locker l2 = new WriteLocker("a", 2, 1000, sb, zkls2);

        new Thread(l1).start();
        Thread.sleep(500);
        new Thread(l2).start();
        Thread.sleep(500);
        l1.finish();
        Thread.sleep(500);
        l2.finish();
        Thread.sleep(500);
        assertEquals("a:1-L a:1-U a:2-L a:2-U", sb.toString().trim());
    }

    public void testTimeoutTimingOutWriteLockThreads() throws Exception {
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            _testTimeoutTimingOutWriteLock(zkls, zkls);
        }
        finally {
            zkls.destroy();
        }
    }

    public void testTimeoutTimingOutWriteLockOozies() throws Exception {
        // Simulate having two different Oozies by using two different ZKLocksServices instead of using the same one in two threads
        ZKLocksService zkls1 = new ZKLocksService();
        ZKLocksService zkls2 = new ZKLocksService();
        try {
            zkls1.init(Services.get());
            zkls2.init(Services.get());
            _testTimeoutTimingOutWriteLock(zkls1, zkls2);
        }
        finally {
            zkls1.destroy();
            zkls2.destroy();
        }
    }

    public void _testTimeoutTimingOutWriteLock(ZKLocksService zkls1, ZKLocksService zkls2) throws Exception {
        StringBuffer sb = new StringBuffer("");
        Locker l1 = new WriteLocker("a", 1, 0, sb, zkls1);
        Locker l2 = new WriteLocker("a", 2, 50, sb, zkls2);

        new Thread(l1).start();
        Thread.sleep(500);
        new Thread(l2).start();
        Thread.sleep(500);
        l1.finish();
        Thread.sleep(500);
        l2.finish();
        Thread.sleep(500);
        assertEquals("a:1-L a:2-N a:1-U", sb.toString().trim());
    }

    public void testReadLockThreads() throws Exception {
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            _testReadLock(zkls, zkls);
        }
        finally {
            zkls.destroy();
        }
    }

    public void testReadLockOozies() throws Exception {
        // Simulate having two different Oozies by using two different ZKLocksServices instead of using the same one in two threads
        ZKLocksService zkls1 = new ZKLocksService();
        ZKLocksService zkls2 = new ZKLocksService();
        try {
            zkls1.init(Services.get());
            zkls2.init(Services.get());
            _testReadLock(zkls1, zkls2);
        }
        finally {
            zkls1.destroy();
            zkls2.destroy();
        }
    }

    public void _testReadLock(ZKLocksService zkls1, ZKLocksService zkls2) throws Exception {
        StringBuffer sb = new StringBuffer("");
        Locker l1 = new ReadLocker("a", 1, -1, sb, zkls1);
        Locker l2 = new ReadLocker("a", 2, -1, sb, zkls2);

        new Thread(l1).start();
        Thread.sleep(500);
        new Thread(l2).start();
        Thread.sleep(500);
        l1.finish();
        Thread.sleep(500);
        l2.finish();
        Thread.sleep(500);
        assertEquals("a:1-L a:2-L a:1-U a:2-U", sb.toString().trim());
    }

    public void testReadWriteLockThreads() throws Exception {
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            _testReadWriteLock(zkls, zkls);
        }
        finally {
            zkls.destroy();
        }
    }

    public void testReadWriteLockOozies() throws Exception {
        // Simulate having two different Oozies by using two different ZKLocksServices instead of using the same one in two threads
        ZKLocksService zkls1 = new ZKLocksService();
        ZKLocksService zkls2 = new ZKLocksService();
        try {
            zkls1.init(Services.get());
            zkls2.init(Services.get());
            _testReadWriteLock(zkls1, zkls2);
        }
        finally {
            zkls1.destroy();
            zkls2.destroy();
        }
    }

    public void _testReadWriteLock(ZKLocksService zkls1, ZKLocksService zkls2) throws Exception {
        StringBuffer sb = new StringBuffer("");
        Locker l1 = new ReadLocker("a", 1, -1, sb, zkls1);
        Locker l2 = new WriteLocker("a", 2, -1, sb, zkls2);

        new Thread(l1).start();
        Thread.sleep(500);
        new Thread(l2).start();
        Thread.sleep(500);
        l1.finish();
        Thread.sleep(500);
        l2.finish();
        Thread.sleep(500);
        assertEquals("a:1-L a:1-U a:2-L a:2-U", sb.toString().trim());
    }

    public void testWriteReadLockThreads() throws Exception {
        ZKLocksService zkls = new ZKLocksService();
        try {
            zkls.init(Services.get());
            _testWriteReadLock(zkls, zkls);
        }
        finally {
            zkls.destroy();
        }
    }

    public void testWriteReadLockOozies() throws Exception {
        // Simulate having two different Oozies by using two different ZKLocksServices instead of using the same one in two threads
        ZKLocksService zkls1 = new ZKLocksService();
        ZKLocksService zkls2 = new ZKLocksService();
        try {
            zkls1.init(Services.get());
            zkls2.init(Services.get());
            _testWriteReadLock(zkls1, zkls2);
        }
        finally {
            zkls1.destroy();
            zkls2.destroy();
        }
    }

    public void _testWriteReadLock(ZKLocksService zkls1, ZKLocksService zkls2) throws Exception {
        StringBuffer sb = new StringBuffer("");
        Locker l1 = new WriteLocker("a", 1, -1, sb, zkls1);
        Locker l2 = new ReadLocker("a", 2, -1, sb, zkls2);

        new Thread(l1).start();
        Thread.sleep(500);
        new Thread(l2).start();
        Thread.sleep(500);
        l1.finish();
        Thread.sleep(500);
        l2.finish();
        Thread.sleep(500);
        assertEquals("a:1-L a:1-U a:2-L a:2-U", sb.toString().trim());
    }
}