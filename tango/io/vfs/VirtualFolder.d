/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Oct 2007: Initial version

        author:         Kris

*******************************************************************************/

module tango.io.vfs.VirtualFolder;

private import tango.io.FileConst;

private import tango.util.PathUtil;

private import tango.core.Exception;

private import tango.io.vfs.model.Vfs;

private import tango.text.Util : head, locatePrior;

/*******************************************************************************
        
        Virtual folders play host to other folder types, including both
        concrete folder instances and subordinate virtual folders. You 
        can build a (singly rooted) tree from a set of virtual and non-
        virtual folders, and treat them as though they were a combined
        or single entity. For example, listing the contents of such a
        tree is no different than listing the contents of a non-virtual
        tree - there's just potentially more nodes to traverse.

*******************************************************************************/

class VirtualFolder : VfsHost
{
        private char[]                  name_;
        private VfsFile[char[]]         files;
        private VfsFolder[char[]]       mounts;
        private VfsFolderEntry[char[]]  folders;
        private VirtualFolder           parent;

        /***********************************************************************

                All folder must have a name. No '.' or '/' chars are 
                permitted

        ***********************************************************************/

        this (char[] name)
        {
                validate (this.name_ = name);
        }

        /***********************************************************************

                Return the (short) name of this folder

        ***********************************************************************/

        final char[] name()
        {
                return name_;
        }

        /***********************************************************************

                Return the (long) name of this folder. Virtual folders 
                do not have long names, since they don't relate directly
                to a concrete folder instance

        ***********************************************************************/

        final char[] toUtf8()
        {
                return name;
        }

        /***********************************************************************

                Add a child folder. The child cannot 'overlap' with others
                in the tree of the same type. Circular references across a
                tree of virtual folders are detected and trapped.

        ***********************************************************************/

        final VfsHost mount (VfsFolder folder)
        {
                assert (folder);

                // link virtual children to us
                auto child = cast(VirtualFolder) folder;
                if (child)
                    if (child.parent)
                        error ("folder '"~folder.name~"' belongs to another host"); 
                    else
                       child.parent = this;

                // reach up to the root, and initiate tree sweep
                auto root = this;
                while (root.parent)
                       if (root is this)
                           error ("circular reference detected while mounting '"~folder.name~"'");
                       else
                          root = root.parent;
                root.mount (folder, true);

                // all clear, so add the new folder
                mounts [folder.name] = folder;
                return this;
        }

        /***********************************************************************

                Unhook a child folder 

        ***********************************************************************/

        final VfsHost dismount (VfsFolder folder)
        {
                assert (folder);

                // reach up to the root, and initiate tree sweep
                auto root = this;
                while (root.parent)
                       root = root.parent;
                root.mount (folder, false);

                mounts[folder.name].remove;
                return this;
        }

        /***********************************************************************

                Add a symbolic link to another file. These are referenced
                by file() alone, and do not show up in tree traversals

        ***********************************************************************/

        final VfsHost map (char[] name, VfsFile file)
        {       
                files[name] = file;
                return this;
        }

        /***********************************************************************

                Add a symbolic link to another folder. These are referenced
                by folder() alone, and do not show up in tree traversals

        ***********************************************************************/

        final VfsHost map (char[] name, VfsFolderEntry folder)
        {       
                folders[name] = folder;
                return this;
        }

        /***********************************************************************

                Iterate over the set of immediate child folders. This is 
                useful for reflecting the hierarchy

        ***********************************************************************/

        final int opApply (int delegate(inout VfsFolder) dg)
        {
                int result;

                foreach (folder; mounts)  
                        {
                        VfsFolder x = folder;  
                        if ((result = dg(x)) != 0)
                             break;
                        }
                return result;
        }

        /***********************************************************************

                Return a folder representation of the given path. If the
                path-head does not refer to an immediate child, and does
                not match a symbolic link, it is considered unknown.

        ***********************************************************************/

        final VfsFolderEntry folder (char[] path)
        {
                char[] tail;
                auto text = head (path, FileConst.PathSeparatorString, tail);

                auto child = text in mounts;
                if (child)
                    return child.folder (tail);
                else
                   {
                   auto sym = text in folders;
                   if (sym)
                       return *sym;
                   }

                error ("'"~text~"' is not a recognized member of '"~name~"'");
        }

        /***********************************************************************

                Return a file representation of the given path. If the
                path-head does not refer to an immediate child folder, 
                and does not match a symbolic link, it is considered unknown.

        ***********************************************************************/

        final VfsFile file (char[] path)
        {
                auto tail = locatePrior (path, FileConst.PathSeparatorChar);
                if (tail < path.length)
                    return folder(path[0..tail]).open.file(path[tail..$]);

                auto sym = path in files;
                if (sym)
                    return *sym;
                error ("'"~path~"' is not a recognized member of '"~name~"'");
        }

        /***********************************************************************

                Remove the entire subtree. Use with caution

        ***********************************************************************/

        final VfsFolder remove ()
        {
                foreach (name, child; mounts)
                         child.remove;
                return this;
        }

        /***********************************************************************

                Returns true if all of the children are writable

        ***********************************************************************/

        final bool isWritable ()
        {
                foreach (name, child; mounts)
                         if (! child.isWritable)
                               return false;
                return true;
        }

        /***********************************************************************

                Returns a folder set containing only this one. Statistics 
                are inclusive of entries within this folder only, which 
                should be zero since symbolic links are not included

        ***********************************************************************/

        final VfsFolders self ()
        {
                return new VirtualFolders (this, false);
        }

        /***********************************************************************

                Returns a subtree of folders. Statistics are inclusive of 
                all files and folders throughout the sub-tree

        ***********************************************************************/

        final VfsFolders tree ()
        {
                return new VirtualFolders (this, true);
        }

        /***********************************************************************

                Sweep the subtree of mountpoints, testing a new folder
                against all others. This propogates a folder test down
                throughout the tree, where each folder implementation
                should take appropriate action

        ***********************************************************************/

        final void mount (VfsFolder folder, bool yes)
        {
                foreach (name, child; mounts)
                         child.mount (folder, yes);
        }

        /***********************************************************************

                Throw an exception

        ***********************************************************************/

        private final char[] error (char[] msg)
        {
                throw new VfsException (msg);
        }

        /***********************************************************************

                Validate path names

        ***********************************************************************/

        private final void validate (char[] name)
        {       
                assert (name);
                if (locatePrior(name, '.') != name.length ||
                    locatePrior(name, FileConst.PathSeparatorChar) != name.length)
                    error ("'"~name~"' contains invalid characters");
        }
}


/*******************************************************************************

        A set of virtual folders. For a sub-tree, we compose the results 
        of all our subordinates and delegate subsequent request to that
        group.

*******************************************************************************/

private class VirtualFolders : VfsFolders
{
        private VfsFolders[] members;           // folders in group

        /***********************************************************************

                Create a subset group

        ***********************************************************************/

        private this () {}

        /***********************************************************************

                Create a folder group including the provided folder and
                (optionally) all child folders

        ***********************************************************************/

        private this (VirtualFolder root, bool recurse)
        {
                if (recurse)
                    foreach (name, folder; root.mounts)
                             members ~= folder.tree;
        }

        /***********************************************************************

                Iterate over the set of contained VfsFolder instances

        ***********************************************************************/

        final int opApply (int delegate(inout VfsFolder) dg)
        {
                int ret;

                foreach (group; members)  
                         foreach (folder; group)
                                 { 
                                 auto x = cast(VfsFolder) folder;
                                 if ((ret = dg(x)) != 0)
                                      break;
                                 }
                return ret;
        }

        /***********************************************************************

                Return the number of files in this group

        ***********************************************************************/

        final uint files ()
        {
                uint files;
                foreach (group; members)
                         files += group.files;
                return files;
        }

        /***********************************************************************

                Return the total size of all files in this group

        ***********************************************************************/

        final ulong bytes ()
        {
                ulong bytes;
                foreach (group; members)
                         bytes += group.bytes;
                return bytes;
        }

        /***********************************************************************

                Return the number of folders in this group

        ***********************************************************************/

        final uint folders ()
        {
                uint count;
                foreach (group; members)
                         count += group.folders;
                return count;
        }

        /***********************************************************************

                Return the total number of entries in this group

        ***********************************************************************/

        final uint entries ()
        {
                uint count;
                foreach (group; members)
                         count += group.entries;
                return count;
        }

        /***********************************************************************

                Return a subset of folders matching the given pattern

        ***********************************************************************/

        final VfsFolders subset (char[] pattern)
        {  
                auto set = new VirtualFolders;

                foreach (group; members)    
                         set.members ~= group.subset (pattern); 
                return set;
        }

        /***********************************************************************

                Return a set of files matching the given pattern

        ***********************************************************************/

        final VfsFiles catalog (char[] pattern)
        {
                return catalog ((VfsInfo info){return patternMatch (info.name, pattern);});
        }

        /***********************************************************************

                Returns a set of files conforming to the given filter

        ***********************************************************************/

        final VfsFiles catalog (VfsFilter filter = null)
        {       
                return new VirtualFiles (this, filter);
        }
}


/*******************************************************************************

        A set of virtual files, represented by composing the results of
        the given set of folders. Subsequent calls are delegated to the
        results from those folders

*******************************************************************************/

private class VirtualFiles : VfsFiles
{
        private VfsFiles[] members;

        /***********************************************************************

        ***********************************************************************/

        private this (VirtualFolders host, VfsFilter filter)
        {
                foreach (group; host.members)    
                         members ~= group.catalog (filter); 
        }

        /***********************************************************************

                Iterate over the set of contained VfsFile instances

        ***********************************************************************/

        final int opApply (int delegate(inout VfsFile) dg)
        {
                int ret;

                foreach (group; members)    
                         foreach (file; group)    
                                  if ((ret = dg(file)) != 0)
                                       break;
                return ret;
        }

        /***********************************************************************

                Return the total number of entries 

        ***********************************************************************/

        final uint files ()
        {
                uint count;
                foreach (group; members)    
                         count += group.files;
                return count;
        }

        /***********************************************************************

                Return the total size of all files 

        ***********************************************************************/

        final ulong bytes ()
        {
                ulong count;
                foreach (group; members)    
                         count += group.bytes;
                return count;
        }
}


debug (Root)
{
/*******************************************************************************

*******************************************************************************/

import tango.io.Stdout;
import tango.io.Buffer;
import tango.io.vfs.FileFolder;

void main()
{
        auto root = new VirtualFolder ("root");
        auto sub  = new VirtualFolder ("sub");
        sub.mount (new FileFolder ("tango", r"d:\d\import\tango"));
        
        root.mount (sub)
            .mount (new FileFolder ("windows", r"c:\"))
            .mount (new FileFolder ("temp", r"d:\d\import\temp"));

        auto folder = root.folder (r"temp\bar");
        Stdout.formatln ("folder = {}", folder);

        root.map ("fsym", root.folder(r"temp\subtree"))
            .map ("wumpus", root.file(r"temp\subtree\test.txt"));
        auto file = root.file (r"wumpus");
        Stdout.formatln ("file = {}", file);
        Stdout.formatln ("fsym = {}", root.folder(r"fsym").open.file("test.txt"));

        foreach (folder; root.folder(r"temp\subtree").open)
                 Stdout.formatln ("folder.child '{}'", folder.name);

        auto set = root.self;
        Stdout.formatln ("self.files = {}", set.files);
        Stdout.formatln ("self.bytes = {}", set.bytes);
        Stdout.formatln ("self.folders = {}", set.folders);

        set = root.folder("temp").open.tree;
        Stdout.formatln ("tree.files = {}", set.files);
        Stdout.formatln ("tree.bytes = {}", set.bytes);
        Stdout.formatln ("tree.folders = {}", set.folders);

        foreach (folder; set)
                 Stdout.formatln ("tree.folder '{}' has {} files", folder.name, folder.self.files);

        auto cat = set.catalog ("*.txt");
        Stdout.formatln ("cat.files = {}", cat.files);
        Stdout.formatln ("cat.bytes = {}", cat.bytes);
        foreach (file; cat)
                 Stdout.formatln ("cat.name '{}' '{}'", file.name, file.toUtf8);
}
}
