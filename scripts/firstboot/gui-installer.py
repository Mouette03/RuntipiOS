#!/usr/bin/env python3
"""
RuntipiOS Graphical Installer
A simple graphical interface for configuring WiFi, SSH user, and password
"""

import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import os
import json

class RuntipiOSInstaller:
    def __init__(self, root):
        self.root = root
        self.root.title("RuntipiOS Configuration")
        self.root.geometry("600x500")
        
        # Variables
        self.has_ethernet = self.check_ethernet()
        self.wifi_ssid = tk.StringVar()
        self.wifi_password = tk.StringVar()
        self.ssh_username = tk.StringVar(value="runtipi")
        self.ssh_password = tk.StringVar()
        self.ssh_password_confirm = tk.StringVar()
        
        self.create_widgets()
        
    def check_ethernet(self):
        """Check if ethernet connection is available"""
        try:
            result = subprocess.run(['ip', 'link', 'show'], 
                                  capture_output=True, text=True)
            return 'eth' in result.stdout or 'enp' in result.stdout
        except:
            return False
    
    def create_widgets(self):
        """Create the GUI widgets"""
        # Main frame
        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Title
        title = ttk.Label(main_frame, text="RuntipiOS Configuration", 
                         font=('Arial', 16, 'bold'))
        title.grid(row=0, column=0, columnspan=2, pady=10)
        
        row = 1
        
        # WiFi configuration (only if no ethernet)
        if not self.has_ethernet:
            ttk.Label(main_frame, text="WiFi Configuration", 
                     font=('Arial', 12, 'bold')).grid(row=row, column=0, 
                     columnspan=2, pady=(10, 5), sticky=tk.W)
            row += 1
            
            ttk.Label(main_frame, text="WiFi SSID:").grid(row=row, column=0, 
                     sticky=tk.W, pady=5)
            ttk.Entry(main_frame, textvariable=self.wifi_ssid, 
                     width=30).grid(row=row, column=1, pady=5)
            row += 1
            
            ttk.Label(main_frame, text="WiFi Password:").grid(row=row, column=0, 
                     sticky=tk.W, pady=5)
            ttk.Entry(main_frame, textvariable=self.wifi_password, 
                     show="*", width=30).grid(row=row, column=1, pady=5)
            row += 1
        else:
            ttk.Label(main_frame, text="Ethernet connection detected", 
                     foreground="green").grid(row=row, column=0, 
                     columnspan=2, pady=10)
            row += 1
        
        # SSH User configuration
        ttk.Label(main_frame, text="SSH User Configuration", 
                 font=('Arial', 12, 'bold')).grid(row=row, column=0, 
                 columnspan=2, pady=(10, 5), sticky=tk.W)
        row += 1
        
        ttk.Label(main_frame, text="Username:").grid(row=row, column=0, 
                 sticky=tk.W, pady=5)
        ttk.Entry(main_frame, textvariable=self.ssh_username, 
                 width=30).grid(row=row, column=1, pady=5)
        row += 1
        
        ttk.Label(main_frame, text="Password:").grid(row=row, column=0, 
                 sticky=tk.W, pady=5)
        ttk.Entry(main_frame, textvariable=self.ssh_password, 
                 show="*", width=30).grid(row=row, column=1, pady=5)
        row += 1
        
        ttk.Label(main_frame, text="Confirm Password:").grid(row=row, column=0, 
                 sticky=tk.W, pady=5)
        ttk.Entry(main_frame, textvariable=self.ssh_password_confirm, 
                 show="*", width=30).grid(row=row, column=1, pady=5)
        row += 1
        
        # Buttons
        button_frame = ttk.Frame(main_frame)
        button_frame.grid(row=row, column=0, columnspan=2, pady=20)
        
        ttk.Button(button_frame, text="Apply Configuration", 
                  command=self.apply_config).pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="Cancel", 
                  command=self.root.quit).pack(side=tk.LEFT, padx=5)
        
    def apply_config(self):
        """Apply the configuration"""
        # Validate inputs
        if not self.ssh_username.get():
            messagebox.showerror("Error", "Username is required")
            return
        
        if not self.ssh_password.get():
            messagebox.showerror("Error", "Password is required")
            return
            
        if self.ssh_password.get() != self.ssh_password_confirm.get():
            messagebox.showerror("Error", "Passwords do not match")
            return
        
        if not self.has_ethernet:
            if not self.wifi_ssid.get():
                messagebox.showerror("Error", "WiFi SSID is required")
                return
        
        # Save configuration
        config = {
            'username': self.ssh_username.get(),
            'password': self.ssh_password.get(),
            'wifi_ssid': self.wifi_ssid.get() if not self.has_ethernet else None,
            'wifi_password': self.wifi_password.get() if not self.has_ethernet else None
        }
        
        try:
            with open('/tmp/runtipios-config.json', 'w') as f:
                json.dump(config, f)
            
            messagebox.showinfo("Success", 
                               "Configuration saved successfully!\n"
                               "The system will now complete the setup.")
            self.root.quit()
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save configuration: {str(e)}")

def main():
    root = tk.Tk()
    app = RuntipiOSInstaller(root)
    root.mainloop()

if __name__ == "__main__":
    main()
