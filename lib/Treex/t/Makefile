#
# This Makefile contains a target to test for memory cycles in Core.
# Please see "TEST OUTPUT" to understand its operation.
#
# To test another block for memory cycles, please follow these guidelines:
#
# You must know the block(s) you want to test and a working scenario
# in which it is (they are) used.
# Let's assume that you want to test a block named SampleBlock.pm
# and the block is used in a scenario Sample.scen
#
# First cd to a directory in which your scenario works (this is due to possible
# relative addresses of input files in the scenario)
#
# Now run the testing script:
# (path-to-this-directory is probably ~/treex/lib/Treex/t/ or alike)
#
# path-to-this-directory/cycle_detection_test.pl Sample.scen SampleBlock.pm
#
# 
# TEST OUTPUT
#
# The testing script modifies the module files (adds cycle detection to them).
# Before it does so, it prints out a warning - if it fails even before printing
# out this warning, it means that the files have not been modified.
#
# If everything works, the scenario is run and at the end you are told that
# it has been run.
# If there are any memory cycles, information about them is printed. It looks
# something like that:
#
# Cycle (1):
#	$Treex::Block::A2N::EN::StanfordNamedEntities::A->{'scenario'} => \%Treex::Core::Scenario::B    
#	$Treex::Core::Scenario::B->{'loaded_blocks'} => \@C                           
#	                       $C->[0] => \%Treex::Block::Util::SetGlobal::D
#	$Treex::Block::Util::SetGlobal::D->{'scenario'} => \%Treex::Core::Scenario::B    
# etc.
# Please consult Devel::Cycle manual for more information.
# 
# In both of the above mentioned cases, the module file(s) are restored to their
# original state after the test, so no further action is needed.
#
# If the run is not successful (maybe dies on a fatal error), the first thing
# you have to do is restore your module file(s), as they have been modified
# but have not been restored because of the premature end of the run.
# For the "cycles_core" target, this is done automatically (as you can see).
# If you ran the cycle_detection_test.pl manually and it failed, you have to
# restore your files manually. This is done by running the restore script, eg.:
#
# path-to-this-directory/cycle_detection_restore.pl SampleBlock.pm
#
# The script restores the module file(s) and prints out info about each file.
#
# If a file cannot be restored, it is probably because of the fact that:
#    a) it has not been changed at all in the first place
#    b) it was changed but has been already restored
# or c) there is an uncommon problem
# The likeliness of the cases follows their order, so usually you do not have to
# worry about that at all.
# If you do, then examine sub add_cycle_detection() in cycle_detection_test.pl
# to see what code is added to the module files and then look for it yourself
# near the end of the module file(s), just before the "1;" statement
# (and delete it if you find it there - that is in fact the whole restore).
#

#test for memory cycles in core
#modifies the module files but restores them at the end of the run
cycles_core:
	-./cycle_detection_test.pl en_analysis.scen ../Core/*.pm ../Core/Node/*.pm
	./cycle_detection_restore.pl ../Core/*.pm ../Core/Node/*.pm > /dev/null

#restore the module files in case cycles_core is interrupted before it restores the files
#if it only fails, the files are recovered automatically
cycles_core_restore:
	./cycle_detection_restore.pl ../Core/*.pm ../Core/Node/*.pm



# Copyright 2011 Rudolf Rosa
