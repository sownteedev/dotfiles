#!/usr/bin/env python3

import os
import sys
from pynvim import attach

def get_all_instances():
    instances = []
    directory_content = os.listdir('/run/user/1000')
    for dirent in directory_content:
        if dirent.startswith('nvim'):
            instances.append('/run/user/1000/' + dirent)
    return instances

def reload_theme(instance, cmd):
    try:
        nvim = attach('socket', path=instance)
    except Exception as e:
        return
    nvim.command(cmd)

def main():
    # search for neovim instances
  instances = get_all_instances()

  # get args
  cmd = sys.argv[1]

  # connect to instances and reload them
  for instance in instances:
      reload_theme(instance, cmd)

if __name__ == '__main__':
    main()
