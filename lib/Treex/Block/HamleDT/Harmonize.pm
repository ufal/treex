package Treex::Block::HamleDT::Harmonize;
use Moose;
use Treex::Core::Common;
use Treex::Core::Coordination;
use Treex::Core::Cloud;
use utf8;
extends 'Treex::Core::Block';
use tagset::common;
use tagset::cs::pdt;

#------------------------------------------------------------------------------
# Reads the a-tree, converts the original morphosyntactic tags to the PDT
# tagset, converts dependency relation tags to afuns and transforms the tree to
# adhere to the PDT guidelines. This method must be overriden in the subclasses
# that know about the differences between the style of their treebank and that
# of PDT. However, here is a sample of what to do. (Actually it's not just a
# sample. You can call it from the overriding method as
# $a_root = $self->SUPER::process_zone($zone);. Call this first and then do
# your specific stuff.)
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $tagset = shift;    # optional argument from the subclass->process_zone()

    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);
    my $a_root = $zone->get_atree();

    # Convert CoNLL POS tags and features to Interset and PDT if possible.
    $self->convert_tags( $a_root, $tagset );

    # Conversion from dependency relation tags to afuns (analytical function tags) must be done always
    # and it is almost always treebank-specific (only a few treebanks use the same tagset as the PDT).
    $self->deprel_to_afun($a_root);

    # Adjust the tree structure. Some of the methods are general, some will be treebank-specific.
    # The decision whether to apply a method at all is always treebank-specific.
    #$self->attach_final_punctuation_to_root($a_root);
    #$self->process_auxiliary_particles($a_root);
    #$self->process_auxiliary_verbs($a_root);
    #$self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
    #$self->check_afuns($a_root);
    # The return value can be used by the overriding methods of subclasses.
    return $a_root;
}

#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $self  = shift;
    my $zone0 = shift;
    return $zone0->copy('orig');
}

#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and PDT tagset.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self   = shift;
    my $root   = shift;
    my $tagset = shift;    # optional, see below
    foreach my $node ( $root->get_descendants() )
    {
        $self->convert_tag( $node, $tagset );
    }
}

#------------------------------------------------------------------------------
# Decodes the part-of-speech tag and features from a CoNLL treebank into
# Interset features. Stores the features with the node. Then sets the tag
# attribute to the closest match in the PDT tagset.
#------------------------------------------------------------------------------
sub convert_tag
{
    my $self   = shift;
    my $node   = shift;
    my $tagset = shift;    # optional tagset identifier (default = 'conll'; sometimes we need 'conll2007' etc.)
    $tagset = 'conll' unless ($tagset);

    # Note that the following hack will not work for all treebanks.
    # Some of them use tagsets not called '*::conll'.
    # Many others are not covered by DZ Interset yet.
    # tagset::common::find_drivers() could help but it would not be efficient to call it every time.
    # Instead, every subclass of this block must know whether to call convert_tag() or not.
    # List of tagsets covered so far:
    my @known_drivers = qw(
        ar::conll ar::conll2007 ar::padt
        bg::conll
        bn::conll
        ca::conll2009
        cs::conll cs::conll2009
        da::conll
        de::conll de::conll2009
        el::conll
        en::conll en::conll2009
        es::conll2009
        eu::conll
        fa::conll
        fi::conll
        grc::conll
        he::conll
        hi::conll
        hu::conll
        it::conll
        ja::conll
        la::conll
        nl::conll
        pl::conll2009 pl::ipipan
        pt::conll
        ro::rdt
        ru::syntagrus
        sl::conll
        sv::conll
        ta::tamiltb
        te::conll
        tr::conll
        zh::conll
    );
    my $driver = $node->get_zone()->language() . '::' . $tagset;
    if ( !grep { $_ eq $driver } (@known_drivers) )
    {
        log_warn("Interset driver $driver not found");
        return;
    }
    # Current tag is probably just a copy of conll_pos.
    # We are about to replace it by a 15-character string fitting the PDT tagset.
    my $tag        = $node->tag();
    my $conll_cpos = $node->conll_cpos();
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    my $src_tag = $tagset eq 'conll2009' ? "$conll_pos\t$conll_feat" : $tagset =~ m/^(conll|tamiltb)/ ? "$conll_cpos\t$conll_pos\t$conll_feat" : $tag;
    my $f = tagset::common::decode($driver, $src_tag);
    my $pdt_tag = tagset::cs::pdt::encode($f, 1);
    $node->set_iset($f);
    $node->set_tag($pdt_tag);
}

#------------------------------------------------------------------------------
# Certain nodes in some treebanks have empty lemmas, although there are lemmas
# in the particular treebank in general. For instance, numbers and punctuation
# symbols in PADT 2.0 lack lemmas. This function makes sure that the lemma
# attribute does not stay empty.
#------------------------------------------------------------------------------
sub fill_in_lemmas
{
    my $self   = shift;
    my $root   = shift;
    foreach my $node ( $root->get_descendants() )
    {
        if(!defined($node->lemma()) || $node->lemma() eq '')
        {
            # Sometimes even the word form is empty. Either it's a bug or these are NULL nodes that also occur in other treebanks.
            if(!defined($node->form()) || $node->form() eq '')
            {
                $node->set_form('<NULL>');
                $node->set_lemma('<NULL>');
            }
            # If there are other instances than numbers and punctuation, we want to know about them.
            elsif($node->get_iset('pos') =~ m/^(num|punc)$/)
            {
                $node->set_lemma($node->form());
            }
        }
    }
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# This abstract class does not understand the source-dependent CoNLL deprels,
# so it only copies them to afuns. The method must be overriden in order to
# produce valid afuns.
#
# List and description of analytical functions in PDT 2.0:
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#
# We define the following pseudo-afuns that are not defined in PDT but are
# useful for the different structures of some treebanks. Note that these
# pseudo-afuns are expected in some methods.
#   PrepArg ... argument of a preposition (typically a noun)
#   SubArg .... argument of a subordinator (typically a verb)
#   NumArg .... argument of a number (counted noun)
#   DetArg .... argument of a determiner (typically a noun)
#   PossArg ... argument of a possessive (possessed noun)
#   AdjArg .... argument of an adjective (modified noun)
#   CoordArg .. coordination member (probably not
#               the first one, in treebanks with different coordinations)
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        $node->set_afun($deprel);
    }
}

#------------------------------------------------------------------------------
# Assigns default afuns. To be used if a node does not have a valid afun value
# and we cannot tell anything more precise about the node.
#------------------------------------------------------------------------------
sub set_default_afun
{
    my $self = shift;
    my $node = shift;
    my $afun;
    my $parent = $node->parent();
    if($parent->is_root())
    {
        # A verb attached directly to root is predicate.
        # There could also be coordination of verbal predicates (possibly nested coordination) but we do not check it at the moment. ###!!!
        if($node->get_iset('pos') eq 'verb')
        {
            $afun = 'Pred';
        }
        else
        {
            $afun = 'ExD';
        }
    }
    else
    {
        # Nominal nodes are modified by attributes, verbal nodes by objects or adverbials.
        # (Adverbials are default because there are typically fewer constraints on them.)
        # Again, we do not check whether the parent is a coordination of verbs. ###!!!
        if($parent->get_iset('pos') eq 'verb')
        {
            $afun = 'Adv';
        }
        else
        {
            $afun = 'Atr';
        }
    }
    $node->set_afun($afun);
}

#------------------------------------------------------------------------------
# After all transformations all nodes must have valid afuns (not our pseudo-
# afuns). Report cases breaching this rule so that we can easily find them in
# Ttred.
#------------------------------------------------------------------------------
sub check_afuns
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ( $afun !~ m/^(Pred|Sb|Obj|Pnom|Adv|Atr|Atv|AtvV|ExD|Coord|Apos|Apposition|Aux[APCVTOYXZGKR]|NR)$/ &&
             # Special tags from the Prague Arabic Dependency Treebank:
             $afun !~ m/^(Pred[ECP]|Ante|Aux[EM])$/
           )
        {
            log_warn($node->get_address());
            $self->log_sentence($root);
            my $ord    = $node->ord();
            my $form   = $node->form();
            my $tag    = $node->tag();
            my $deprel = $node->conll_deprel();

            # This cannot be fatal if we want the trees to be saved and examined in Ttred.
            if ($afun)
            {
                log_warn("Node $ord:$form/$tag/$deprel still has the pseudo-afun $afun.");

                # Erase the pseudo-afun to avoid further complaints of Treex and Tred.
                log_info("Removing the pseudo-afun...");
                $node->set_afun('NR');
            }
            else
            {
                log_warn("Node $ord:$form/$tag/$deprel still has no afun.");
                $node->set_afun('NR');
            }
        }
    }
}

#------------------------------------------------------------------------------
# Shifts afun from preposition (subordinating conjunction) to its argument and
# gives the preposition (conjunction) new afun 'AuxP' ('AuxC'). Useful for
# treebanks where prepositions and subordinating conjunctions bear the deprel
# of their subtree. The subclass should not call this method before it assigns
# or pseudo-afuns to all nodes. Arguments of prepositions (subordinating
# conjunctions) must have the pseudo-afun 'PrepArg' ('SubArg'). There should
# be just one child with such afun.
#
# Call from the end of deprel_to_afun() like this:
# $self->process_prep_sub_arg($root);
#
# Tells the parent node whether the child node wants to take the parent's afun
# and return 'AuxP' or 'AuxC' instead. Called recursively. In some treebanks
# there may be chains of both AuxP and AuxC such as in this Danish example:
# parate/AA/pred til/RR/pobj at/TT/nobj gå/Vf/vobj =>
# parate/AA/Pnom til/RR/AuxP at/TT/AuxC gå/Vf/Atr

###!!!
# Je tu ale problém. Jestliže ještě nemáme vyřešené koordinace, může nám tahle
# operace znemožnit jejich identifikaci. (Ovšem asi platí i naopak, že při
# zpracování koordinací bychom se rádi spolehli na definované chování AuxP a
# AuxC.)
###!!!

#------------------------------------------------------------------------------
sub process_prep_sub_arg
{
    my $self                = shift;
    my $node                = shift;
    my $parent_current_afun = shift;
    my $parent_new_afun     = $parent_current_afun;
    my $current_afun        = $node->afun();
    $current_afun = '' if(!defined($current_afun));

    # If I am currently a prep/sub argument, let's steal the parent's afun.
    if ( $current_afun eq 'PrepArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxP';
    }
    elsif ( $current_afun eq 'SubArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxC';
    }

    # Now let's see whether my children want my afun.
    my $new_afun = $current_afun;
    my @children = $node->children();
    my $argument_found = 0;
    foreach my $child (@children)
    {

        # Ask a child if it wants my afun and what afun it thinks I should get.
        # A preposition can have more than one child and some of the children may not be PrepArgs.
        # So only set $new_afun if it really differs from $current_afun
        # (otherwise the first child could propose a change and the second could revert it).
        my $suggested_afun = $self->process_prep_sub_arg( $child, $current_afun );
        if($suggested_afun ne $current_afun)
        {
            # Even if the preposition has several children, only one can be PrepArg.
            # Otherwise it would not be clear what to do.
            # (Note however that there is no warranty that the input data is clean.)
            if($argument_found)
            {
                log_warn("Two or more Prep/SubArg children under one preposition/conjunction.\n".$node->get_address());
            }
            $new_afun = $suggested_afun;
            $argument_found = 1;
        }
    }
    # Set the afun my children selected (it is either my current afun or 'AuxP' or 'AuxC').
    $node->set_afun($new_afun);

    # Let the parent know what I selected for him.
    return $parent_new_afun;
}

sub process_prep_sub_arg_cloud
{
    my $self = shift;
    my $root = shift;
    # Convert the tree of nodes to tree of clouds, i.e. build the parallel structure.
    my $cloud = new Treex::Core::Cloud;
    $cloud->create_from_node($root);
    # Traverse the tree of clouds.
    $self->process_prep_sub_arg_cloud_recursive($cloud);
    $cloud->destroy_children();
}
###!!! DOKONČIT
sub process_prep_sub_arg_cloud_recursive
{
    my $self                = shift;
    my $cloud               = shift;
    my $parent_current_afun = shift;
    my $parent_new_afun     = $parent_current_afun;
    my $current_afun        = $cloud->afun();
    $current_afun = '' if(!defined($current_afun));

    # If I am currently a prep/sub argument, let's steal the parent's afun.
    if ( $current_afun eq 'PrepArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxP';
    }
    elsif ( $current_afun eq 'SubArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxC';
    }

    # Now let's see whether my children want my afun.
    my $new_afun = $current_afun;
    # Recursion that traverses the whole tree means that we go to both participants and modifiers.
    # But we cannot work with both the same way.
    # We cannot compare participants' afun with the afun of the coordination cloud: they should be identical!
    my @children = $cloud->get_shared_modifiers();
    my @participants = $cloud->get_participants();
    my $argument_found = 0;
    foreach my $child (@children)
    {

        # Ask a child if it wants my afun and what afun it thinks I should get.
        # A preposition can have more than one child and some of the children may not be PrepArgs.
        # So only set $new_afun if it really differs from $current_afun
        # (otherwise the first child could propose a change and the second could revert it).
        my $suggested_afun = $self->process_prep_sub_arg_cloud_recursive( $child, $current_afun );
        if($suggested_afun ne $current_afun)
        {
            # Even if the preposition has several children, only one can be PrepArg.
            # Otherwise it would not be clear what to do.
            # (Note however that there is no warranty that the input data is clean.)
            if($argument_found)
            {
                log_warn("Two or more Prep/SubArg children under one preposition/conjunction.");
            }
            $new_afun = $suggested_afun;
            $argument_found = 1;
        }
    }
    foreach my $participant (@participants)
    {
        # A non-trivial cloud, e.g. coordination, cannot accept AuxP suggestions from its participants.
        # In particular, coordination should have the same afun as most if not all its conjuncts.
        # We will recurse to participants so that anything within their subtrees can be processed
        # but we will ignore their suggestions going back up.
        my $ignored_suggestion = $self->process_prep_sub_arg_cloud_recursive($participant, $parent_current_afun);
    }
    # Set the afun my children selected (it is either my current afun or 'AuxP' or 'AuxC').
    $cloud->set_afun($new_afun);

    # Let the parent know what I selected for him.
    return $parent_new_afun;
}

#------------------------------------------------------------------------------
# Returns the noun phrase attached directly to the preposition in a
# prepositional phrase. It is difficult to detect without understanding the
# treebank-specific dependency relation tags because the preposition may have
# more than one child (coordination members if the preposition governed
# a coordination; modifiers (intensifiers) of the whole PP if the guidelines
# rule to attach them to the preposition) and the main child need not be
# necessarily a noun (it could be an adjective, a numeral etc.)
#------------------------------------------------------------------------------
sub get_preposition_argument
{
    my $self     = shift;
    my $prepnode = shift;

    # The assumption is that the preposition governs the noun phrase and not vice versa.
    # If not, run the corresponding transformation prior to calling this method.
    # We cannot reliably assume that a preposition has only one child.
    # There may be rhematizers modifying the whole prepositional phrase.
    # We assume that the real argument of the preposition can only have one of selected parts of speech and afuns.
    # (Note that PrepArg is a pseudo-afun that is not defined in PDT but subclasses can use it to explicitly mark preposition arguments
    # whenever no other suitable afun is readily available.)
    my @prepchildren = grep { $_->afun() eq 'PrepArg' } ( $prepnode->children() );
    if (@prepchildren)
    {
        if ( scalar(@prepchildren) > 1 )
        {
            $self->log_sentence($prepnode);
            log_info( "Preposition " . $prepnode->ord() . ":" . $prepnode->form() );
            log_warn("More than one preposition argument.");
        }
        return $prepchildren[0];
    }
    else
    {
        @prepchildren = grep { $_->get_iset('pos') =~ m/^(noun|adj|num)$/ } ( $prepnode->children() );
        if (@prepchildren)
        {
            if ( scalar(@prepchildren) > 1 )
            {
                $self->log_sentence($prepnode);
                log_info( "Preposition " . $prepnode->ord() . ":" . $prepnode->form() );
                log_warn("More than one preposition argument.");
            }
            return $prepchildren[0];
        }
        else
        {
            @prepchildren = grep { $_->afun() =~ m/^(Sb|Obj|Pnom|Adv|Atv|Atr)$/ } ( $prepnode->children() );
            if (@prepchildren)
            {
                if ( scalar(@prepchildren) > 1 )
                {
                    $self->log_sentence($prepnode);
                    log_info( "Preposition " . $prepnode->ord() . ":" . $prepnode->form() );
                    log_warn("More than one preposition argument.");
                }
                return $prepchildren[0];
            }
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Returns the clause attached directly to the subordinating conjunction. It is
# difficult to detect without understanding the treebank-specific dependency
# relation tags because the conjunction may have more than one child
# (coordination members if the conjunction governed a coordination).
#------------------------------------------------------------------------------
sub get_subordinator_argument
{
    my $self        = shift;
    my $subnode     = shift;
    my @subchildren = grep { $_->afun() eq 'SubArg' } ( $subnode->children() );
    if (@subchildren)
    {
        if ( scalar(@subchildren) > 1 )
        {
            $self->log_sentence($subnode);
            log_info( "Subordinator " . $subnode->ord() . ":" . $subnode->form() );
            log_warn("More than one subordinator argument.");
        }
        return $subchildren[0];
    }
    else
    {
        @subchildren = grep { $_->get_iset('pos') =~ m/^(verb)$/ } ( $subnode->children() );
        if (@subchildren)
        {
            if ( scalar(@subchildren) > 1 )
            {
                $self->log_sentence($subnode);
                log_info( "Subordinator " . $subnode->ord() . ":" . $subnode->form() );
                log_warn("More than one subordinator argument.");
            }
            return $subchildren[0];
        }
    }
    return undef;
}

sub attach_final_punctuation_to_root {
    my ($self, $root) = @_;
    $self->get_or_load_other_block(
        'HamleDT::AttachFinalPunctuationToRoot')->process_atree($root);
}

#------------------------------------------------------------------------------
# Restructures coordinations to the Prague style.
# Calls a treebank-specific method detect_coordination() that fills a list of
# arrays, each containing a hash with the following keys:
# - members: list of nodes that are members of coordination
# - delimiters: list of nodes with commas or conjunctions between the members
# - shared_modifiers: list of nodes that depend on the whole coordination
# - parent: the node the coordination modifies
# - afun: the analytical function of the whole coordination wrt. its parent
#------------------------------------------------------------------------------
sub restructure_coordination
{
    my $self  = shift;
    my $root  = shift;
    my $debug = shift;

    #my $debug = $self->sentence_contains($root, 'Spürst du das');
    log_info('DEBUG ON') if ($debug);

    # Switch between approaches to solving coordination.
    # The former reshapes coordination immediately upon finding it.
    # The latter and older approach first collects all coord structures then reshapes them.
    # It could theoretically suffer from things changing during reshaping.
    my $test_result = $self->detect_coordination($root, new Treex::Core::Coordination);
    my $implemented = !(defined($test_result) && $test_result eq 'not implemented');
    if ($implemented)
    {
        $self->shape_coordination_recursively_object( $root, $debug );
    }
    elsif (1)
    {
        $self->shape_coordination_recursively( $root, $debug );
    }
    else
    {
        my @coords;

        # Collect information about all coordination structures in the tree.
        $self->detect_coordination( $root, \@coords );

        # Loop over coordinations and restructure them.
        # Hopefully the order in which the coordinations are processed is not significant.
        foreach my $c (@coords)
        {
            $self->shape_coordination( $c, $debug );
        }
    }
}

#------------------------------------------------------------------------------
###!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!###
# Every descendant of this class should implement its own method
# detect_coordination(). It may use the prepared detect_...() methods of
# Coordination but it must select what annotation style is to be expected in
# the data. During the transition phase, until all descendants have implemented
# the method, we will keep here the functions that take the old approach. In
# order to recognize when to use them, we need a bogus implementation of the
# new function that just says 'not implemented'.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    return 'not implemented';
}

#------------------------------------------------------------------------------
# A different approach: recursively search for coordinations and solve them
# immediately, i.e. don't collect all first.
#------------------------------------------------------------------------------
sub shape_coordination_recursively
{
    my $self  = shift;
    my $root  = shift;
    my $debug = shift;

    # Is the current subtree root a coordination root?
    # Look for coordination members.
    my @members;
    my @delimiters;
    my @sharedmod;
    my @privatemod;
    my %coord =
        (
        'members'           => \@members,
        'delimiters'        => \@delimiters,
        'shared_modifiers'  => \@sharedmod,
        'private_modifiers' => \@privatemod,    # for debugging purposes only
        'oldroot'           => $root
        );
    $self->collect_coordination_members( $root, \@members, \@delimiters, \@sharedmod, \@privatemod, $debug );
    if (@members)
    {
        log_info('COORDINATION FOUND') if ($debug);

        # We have found coordination! Solve it right away.
        $self->shape_coordination( \%coord, $debug );

        # Call recursively on all modifier subtrees.
        # Do not call it on all children because they include members and delimiters.
        # Non-first members cannot head nested coordination under this approach.
        ###!!! TO DO: Make this function independent on coord approach taken in the current treebank!
        ###!!! Possible solution: collect_coordination_members() also returns the list of nodes for recursive search.
        # All CoordArg children they may have are considered members of the current coordination.
        foreach my $node ( @sharedmod, @privatemod )
        {
            $self->shape_coordination_recursively( $node, $debug );
        }
    }

    # Call recursively on all children if no coordination detected now.
    else
    {
        foreach my $child ( $root->children() )
        {
            $self->shape_coordination_recursively( $child, $debug );
        }
    }
}

#------------------------------------------------------------------------------
# A different approach: recursively search for coordinations and solve them
# immediately, i.e. don't collect all first.
# Use the Coordination object.
#------------------------------------------------------------------------------
sub shape_coordination_recursively_object
{
    my $self  = shift;
    my $root  = shift;
    my $debug = shift;
    my $coordination = new Treex::Core::Coordination;
    my @recursion = $self->detect_coordination($root, $coordination, $debug);
    if(scalar($coordination->get_conjuncts())>0)
    {
        log_info('COORDINATION FOUND') if ($debug);

        # We have found coordination! Solve it right away.
        $coordination->shape_prague();

        # Call recursively on all descendants. (The exact recursive set depends on annotation style.
        # We got it from detect_coordination().)
        foreach my $node (@recursion)
        {
            $self->shape_coordination_recursively_object($node, $debug);
        }
    }
    # Call recursively on all children if no coordination detected now.
    else
    {
        foreach my $child ($root->children())
        {
            $self->shape_coordination_recursively_object($child, $debug);
        }
    }
}

#------------------------------------------------------------------------------
# Restructures one coordination structure to the Prague style.
# Takes a description of the structure as a hash with the following keys:
# - members: list of nodes that are members of coordination
# - delimiters: list of nodes with commas or conjunctions between the members
# - shared_modifiers: list of nodes that depend on the whole coordination
# - private_modifiers: list of nodes that depend on individual members
#     for debugging purposes only
# - oldroot: the original root node of the coordination (e.g. the first member)
#     parent and afun of the whole structure is taken from oldroot
#------------------------------------------------------------------------------
sub shape_coordination
{
    my $self  = shift;
    my $c     = shift;    # reference to hash
    my $debug = shift;
    $debug = 0 if ( !defined($debug) );
    if ( $debug >= 1 )
    {
        $self->log_sentence( $c->{oldroot} );
        log_info( "Coordination members:    " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{members} } ) ) );
        log_info( "Coordination delimiters: " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{delimiters} } ) ) );
        log_info( "Coordination modifiers:  " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{shared_modifiers} } ) ) );
        if ( exists( $c->{private_modifiers} ) )
        {
            log_info( "Member modifiers:        " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{private_modifiers} } ) ) );
        }
        log_info( "Old root:                " . $c->{oldroot}->ord() . ':' . $c->{oldroot}->form() );
    }
    elsif ( $debug > 0 )
    {
        my @cnodes = sort { $a->ord() <=> $b->ord() } ( @{ $c->{members} }, @{ $c->{delimiters} } );
        log_info( join( ' ', map { $_->ord() . ':' . $_->form() } (@cnodes) ) );
    }

    # Get the parent and afun of the whole coordination, from the old root of the coordination.
    # Note that these may have changed since the coordination was detected,
    # as a result of processing other coordinations, if this is a nested coordination.
    my $parent = $c->{oldroot}->parent();
    if ( !defined($parent) )
    {
        $self->log_sentence( $c->{oldroot} );
        log_fatal('Coordination has no parent.');
    }

    # Select the last delimiter as the new root.
    if ( !@{ $c->{delimiters} } )
    {

        # It can happen, however rare, that there are no delimiters between the coordinated nodes.
        # Example: de:
        #   `` Spürst du das ? '' , fragt er , `` spürst du den Knüppel ?
        # Here, both direct speeches are coordinated and together attached to 'fragt'.
        # All punctuation is also attached to 'fragt', it is thus not available as coordination delimiters.
        # We have to be robust and to survive such cases.
        # Since there seems to be no better solution, the first member of the coordination will become the root.
        # It will no longer be recognizable as coordination member. The coordination may now be deficient and have only one member.
        # If it was already a deficient coordination, i.e. if it had no delimiters and only one member, then something went wrong
        # (probably it is no coordination at all).
        log_fatal('Coordination has fewer than two members and no delimiters.') if ( scalar( @{ $c->{members} } ) < 2 );
        push( @{ $c->{delimiters} }, shift( @{ $c->{members} } ) );
    }
    # There is no guarantee that we obtained ordered lists of members and delimiters.
    # They may have been added during tree traversal, which is not ordered linearly.
    my @ordered_members  = sort {$a->ord() <=> $b->ord()} (@{$c->{members}});
    my @ordered_delimiters = sort {$a->ord() <=> $b->ord()} (@{$c->{delimiters}});

    # If the last delimiter is punctuation and it occurs after the last member
    # and there is at least one delimiter before the last member, choose this other delimiter.
    # We try to avoid non-coordinating punctuation such as quotation marks after the sentence.
    # However, some non-punctuation delimiters can occur after the last member. Example: "etc".
    my $first_member_ord = $ordered_members[0]->ord();
    my $last_member_ord  = $ordered_members[$#ordered_members]->ord();
    my @inner_delimiters = grep { $_->ord() > $first_member_ord && $_->ord() < $last_member_ord } (@ordered_delimiters);
    my $croot            = scalar(@inner_delimiters) ? pop(@inner_delimiters) : pop(@ordered_delimiters);

    # Attach the new root to the parent of the coordination.
    $croot->set_parent($parent);

    # Attach all coordination members to the new root.
    foreach my $member ( @{ $c->{members} } )
    {
        $member->set_parent($croot);
        $member->set_is_member(1);
    }

    # Attach all remaining delimiters to the new root.
    foreach my $delimiter ( @{ $c->{delimiters} } )
    {

        # The $croot is not guaranteed to be removed from delimiters if it was an inner delimiter.
        next if ( $delimiter == $croot );
        $delimiter->set_parent($croot);
        if ( $delimiter->form() eq ',' )
        {
            $delimiter->set_afun('AuxX');
        }
        elsif ( $delimiter->get_iset('pos') =~ m/^(conj|adv|part)$/ )
        {
            $delimiter->set_afun('AuxY');
        }
        else
        {
            $delimiter->set_afun('AuxG');
        }
    }

    # Now that members and delimiters are restructured, set also the afuns of the members.
    # Do not ask the former root about its real afun earlier.
    # If it is a preposition and the coordination members still sit among its children, the preposition may not know where to find its real afun.
    my $afun = $c->{oldroot}->get_real_afun() || '';
    $croot->set_afun('Coord');
    foreach my $member ( @{ $c->{members} } )
    {

        # Assign the afun of the whole coordination to the member.
        # Prepositional members require special treatment: the afun goes to the argument of the preposition.
        # Some members are in fact orphan dependents of an ellided member.
        # Their current afun is ExD and they shall keep it, unlike the normal members.
        $member->set_real_afun($afun) unless ( $member->afun() eq 'ExD' );
    }

    # Attach all shared modifiers to the new root.
    foreach my $modifier ( @{ $c->{shared_modifiers} } )
    {
        $modifier->set_parent($croot);
    }
}

#------------------------------------------------------------------------------
# Several treebanks solve apposition so that the second member is attached to
# the first member and marked using a special dependency relation tag. Changing
# this tag to the Apos afun is not enough Praguish: in reality we want to find
# a suitable punctuation in between, make it the Apos root and attach both
# members to it. Before we implement this behavior we may want to apply the
# poor-man's solution (just to make sure that there are no invalid Apos
# structures): remove any Apos afuns and replace them by Atr.
#------------------------------------------------------------------------------
sub shape_apposition
{
    my $self = shift;
    my $node = shift;
    if($node->afun() eq 'Apos')
    {
        $node->set_afun('Atr');
    }
    foreach my $child ($node->children())
    {
        $self->shape_apposition($child);
    }
}

#------------------------------------------------------------------------------
# This method is called for coordination and apposition nodes whose members do
# not have the is_member attribute set (e.g. in Arabic and Slovene treebanks
# the information was lost in conversion to CoNLL). It estimates, based on
# afuns, which children are members and which are shared modifiers.
#------------------------------------------------------------------------------
sub identify_coap_members
{
    my $self = shift;
    my $coap = shift;
    return unless($coap->afun() =~ m/^(Coord|Apos)$/);
    # We should not estimate coap membership if it is already known!
    foreach my $child ($coap->children())
    {
        if($child->is_member())
        {
            log_warn('Trying to estimate CoAp membership of a node that is already marked as member.');
        }
    }
    # Get the list of nodes involved in the structure.
    my @involved = $coap->get_children({'ordered' => 1, 'add_self' => 1});
    # Get the list of potential members and modifiers, i.e. drop delimiters.
    # Note that there may be more than one Coord|Apos node involved if there are nested structures.
    # We simplify the task by assuming (wrongly) that nested structures are always members and never modifiers.
    # Delimiters can have the following afuns:
    # Coord|Apos ... the root of the structure, either conjunction or punctuation
    # AuxY ... other conjunction
    # AuxX ... comma
    # AuxG ... other punctuation
    my @memod = grep {$_->afun() !~ m/^Aux[GXY]$/ && $_!=$coap} (@involved);
    # If there are only two (or fewer) candidates, consider both members.
    if(scalar(@memod)<=2)
    {
        foreach my $m (@memod)
        {
            $m->set_is_member(1);
        }
    }
    else
    {
        # Hypothesis: all members typically have the same afun.
        # Find the most frequent afun among candidates.
        # For the case of ties, remember the first occurrence of each afun.
        # Do not count nested 'Coord' and 'Apos': these are jokers substituting any member afun.
        # Same for 'ExD': these are also considered members (in fact they are children of an ellided member).
        my %count;
        my %first;
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            next if($afun =~ m/^(Coord|Apos|ExD)$/);
            $count{$afun}++;
            $first{$afun} = $m->ord() if(!exists($first{$afun}));
        }
        # Get the winning afun.
        my @afuns = sort
        {
            my $result = $count{$b} <=> $count{$a};
            unless($result)
            {
                $result = $first{$a} <=> $first{$b};
            }
            return $result;
        }
        (keys(%count));
        # Note that there may be no specific winning afun if all candidate afuns were Coord|Apos|ExD.
        my $winner = @afuns ? $afuns[0] : '';
        ###!!! If the winning afun is 'Atr', it is possible that some Atr nodes are members and some are shared modifiers.
        ###!!! In such case we ought to check whether the nodes are delimited by a delimiter.
        ###!!! This has not yet been implemented.
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            if($afun eq $winner || $afun =~ m/^(Coord|Apos|ExD)$/)
            {
                $m->set_is_member(1);
            }
        }
    }
}

#------------------------------------------------------------------------------
# Conjunction (such as 'and', 'but') occurring as the first word of the
# sentence should be analyzed as deficient coordination whose only member is
# the main verb of the main clause.
#------------------------------------------------------------------------------
sub mark_deficient_clausal_coordination
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants( { ordered => 1 } );
    if ( $nodes[0]->afun() eq 'Coord' && scalar($nodes[0]->get_coap_members())==0 )
    {
        my $croot = $nodes[0];
        my @root_children = $root->children();
        # Do not reattach $croot earlier because it must not be one of @root_children.
        # Do not reattach it later because Treex might complain about cycles.
        $croot->set_parent($root);
        foreach my $rc (@root_children)
        {
            next if($rc==$croot);
            # The sentence-final punctuation must stay at the upper level.
            next if($rc->afun() eq 'AuxK');
            $rc->set_parent($croot);
            $rc->set_is_member(1) unless($rc->afun() =~ m/^Aux[GXY]$/);
        }
        # It is not guaranteed that $croot now has coordination members.
        # If we were not able to find nodes elligible as members, we must not tag $croot as Coord.
        if(scalar($croot->get_coap_members())==0)
        {
            $croot->set_afun('ExD');
        }
    }
}

#------------------------------------------------------------------------------
# Validates coordination/apposition structures.
# - A Coord/Apos node must have at least one member.
# - A node with is_member set must have a Coord/Apos parent.
# - Note that is_member is now set directly under the Coord/Apos node,
#   regardless of prepositions and subordinating conjunctions.
# - Members should not have afuns AuxX (comma), AuxG (other punctuation) and
#   AuxY (other words, e.g. parts of multi-word coordinating conjunction).
#------------------------------------------------------------------------------
sub validate_coap
{
    my $self = shift;
    my $node = shift;
    my $afun = $node->afun();
    my @children = $node->get_children();
    if($afun =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} (@children))
    {
        $self->log_sentence($node);
        log_warn("The $afun node #".$node->ord()." '".$node->form()."' is missing coap members.");
    }
    if($node->is_member())
    {
        if($node->parent()->afun() !~ m/^(Coord|Apos)$/)
        {
            $self->log_sentence($node);
            log_warn("The member node #".$node->ord()." '".$node->form()."' does not have a coap parent.");
        }
        if($afun =~ m/^Aux[GXY]$/)
        {
            $self->log_sentence($node);
            log_warn("The node #".$node->ord()." '".$node->form()."' should be either coap member or $afun but not both.");
        }
    }
    foreach my $child (@children)
    {
        $self->validate_coap($child);
    }
}

#------------------------------------------------------------------------------
# Swaps node with its parent. The original parent becomes a child of the node.
# All other children of the original parent become children of the node. The
# node also keeps its original children.
#
# The lifted node gets the afun of the original parent while the original
# parent gets a new afun. The conll_deprel attribute is changed, too, to
# prevent possible coordination destruction.
#
# If the original parent had is_member set, the flag will be moved to the
# lifted node. If the lifted node had is_member set, we must lift the whole
# coordination! If the original parent is Coord and the lifted node is a shared
# modifier of coordination, we must be careful with reattaching the original
# siblings of the lifted node. Only other shared modifiers can be reattached.
#------------------------------------------------------------------------------
sub lift_node
{
    my $self   = shift;
    my $node   = shift;
    my $afun   = shift;             # new afun for the old parent
    my $parent = $node->parent();
    confess('Cannot lift a child of the root') if ( $parent->is_root() );
    my $grandparent = $parent->parent();

    # Lifting a conjunct means lifting the whole coordination!
    unless($node->is_member())
    {
        # Reattach myself to the grandparent.
        $node->set_parent($grandparent);
        # If parent is coordination, we need the afun of the conjuncts.
        $node->set_afun($parent->get_real_afun());
        $node->set_is_member( $parent->is_member() );
        $node->set_conll_deprel( $parent->conll_deprel() );
        # Reattach all previous siblings to myself.
        foreach my $sibling ( $parent->children() )
        {
            # No need to test whether $sibling==$node as we already reattached $node.
            # If parent is Coord, reattach modifiers but not conjuncts!
            unless($parent->afun() eq 'Coord' && ($sibling->is_member() || $sibling->afun() =~ m/^Aux[GXY]$/))
            {
                $sibling->set_parent($node);
            }
        }
        # Reattach the previous parent to myself.
        $parent->set_parent($node);
        # If parent is coordination, we must set afun of its conjuncts.
        $parent->set_real_afun($afun);
        $parent->set_is_member(0);
        $parent->set_conll_deprel('');
    }
    else # lift coordination
    {
        my $coordination = new Treex::Core::Coordination;
        $coordination->detect_prague($parent);
        # Now redefine parent and grandparent to those of the whole coordination.
        my $coordroot = $parent;
        $parent = $grandparent;
        confess('Cannot lift a child of the root') if ( $parent->is_root() );
        $grandparent = $parent->parent();
        # Reattach coordination to the grandparent.
        $coordination->set_parent($grandparent);
        # If parent is coordination, we need the afun of the conjuncts.
        $coordination->set_afun($parent->get_real_afun());
        $coordroot->set_is_member($parent->is_member());
        # Reattach all previous siblings to myself.
        foreach my $sibling ($parent->children())
        {
            unless($sibling==$coordroot)
            {
                # If parent is Coord, reattach modifiers but not conjuncts!
                unless($parent->afun() eq 'Coord' && ($sibling->is_member() || $sibling->afun() =~ m/^Aux[GXY]$/))
                {
                    $coordination->add_shared_modifier($sibling);
                }
            }
        }
        # Reattach the previous parent to myself.
        $coordination->add_shared_modifier($parent);
        # If parent is coordination, we must set afun of its conjuncts.
        $parent->set_real_afun($afun);
        $parent->set_is_member(0);
        $parent->set_conll_deprel('');
        $coordination->shape_prague();
    }
}

#------------------------------------------------------------------------------
# Writes the current sentence including the sentence number to the log. To be
# used together with warnings so that the problematic sentence can be localized
# and examined in Ttred.
#------------------------------------------------------------------------------
sub log_sentence
{
    my $self = shift;
    my $node = shift;
    my $root = $node->get_root();

    # get_position() returns numbers from 0 but Tred numbers sentences from 1.
    my $i = $root->get_bundle()->get_position() + 1;
    log_info( "\#$i " . $root->get_zone()->sentence() );
}

#------------------------------------------------------------------------------
# Returns 1 if the sentence of a given node contains a given substring (mind
# tokenization). Returns 0 otherwise. Can be used to easily focus debugging on
# a problematic sentence like this:
# $debug = $self->sentence_contains($node, 'sondern auch mit Instrumenten');
#------------------------------------------------------------------------------
sub sentence_contains
{
    my $self     = shift;
    my $node     = shift;
    my $query    = shift;
    my $sentence = $node->get_zone()->sentence();
    return $sentence =~ m/$query/;
}

#------------------------------------------------------------------------------
# Error handler: removes 'is_member' attribute if the node is not
# part of the coordination structure.
#------------------------------------------------------------------------------
sub remove_ismember_membership
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes) {
        if ($node->is_member) {
            my $parnode = $node->get_parent();
            if (defined $parnode) {
                my $parafun = $parnode->afun();
                if ($parafun !~ /^(Coord|Apos)$/) {# remove the 'is_member'
                    $node->set_is_member(0);
                }
            }
        }
    }
}

# Global counter over all documents.
###!!! We only need it for investigation of the source data. Once done, we will adjust routines and stop collecting statistics.
# How to access it in functions:
# my $counter = $self->_counter();
# $counter->{xxx}++;
# How to print the final counts: use sub process_end();
has _counter => ( is => 'ro', default => sub { {} } );

#------------------------------------------------------------------------------
# Collects statistics of ways in which coordination is annotated.
#------------------------------------------------------------------------------
sub investigate_coordinations
{
    my $self = shift;
    my $root = shift;
    my $counter = $self->_counter();
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # Nodes with afuns 'Coord' and 'CoordArg' participate in coordinations.
        # Nodes with afun 'ExD' participate if their parent is 'Coord'.
        # (There may be orphans of conjuncts that were not connected via any conjunction, thus no 'Coord'. But there is no way to recognize them.)
        # Ignore additional conjunctions and punctuation at the moment.
        my $afun = $node->afun();
        if($afun =~ m/^Coord(Arg)?$/ ||
           $afun eq 'ExD' && defined($node->parent()) && $node->parent()->afun() eq 'Coord')
        {
            # Find the root node of the coordination.
            # Do not recognize nested coordinations. Traverse ancestors until their afun is not coordinational.
            # (Possibilities to annotate nested coordination under the Danish scheme are limited anyway.)
            my $coordroot = $node;
            while(1)
            {
                my $parent = $coordroot->parent();
                if(!defined($parent))
                {
                    log_warn("A node that ought to participate in coordination has no parent.");
                    ###!!! Co teď? Přeskočit ho? Nebo s ním naložit, jako kdyby to byl kořen koordinace?
                    last;
                }
                $coordroot = $parent;
                if($coordroot->afun() !~ m/^Coord(Arg)?$/)
                {
                    # The dependency relation of this node to its parent is not coordinational.
                    # Thus this is the root (head) node of the coordination.
                    last;
                }
            }
            # The node participates in a coordination and we know the root of the coordination.
            # Store links to all participating nodes at the coordination root.
            # Note that the coordination root itself will not be part of this array because it does not have a coordinational afun.
            push(@{$coordroot->{coordination_nodes}}, $node);
        }
    }
    # All coordination roots now know that they govern coordinations and they know all participating nodes.
    foreach my $node (@nodes)
    {
        if(exists($node->{coordination_nodes}))
        {
            my @conodes = @{$node->{coordination_nodes}};
            if(scalar(@conodes)>=1)
            {
                # Include the coordination root in the nodes. Order them according to the sentence.
                push(@conodes, $node);
                @conodes = sort {$a->ord() <=> $b->ord()} (@conodes);
                # A typical coordination will have three nodes: two conjuncts and a conjunction.
                # Coordination signature: parents and afuns.
                for(my $i = 0; $i<=$#conodes; $i++)
                {
                    $conodes[$i]{coindex} = $i+1;
                }
                $node->parent()->{coindex} = 0;
                my $n = scalar(grep {$_->afun() ne 'Coord'} (@conodes));
                my $signature = sprintf("%02d", $n).' '.join(' ', map {my $p = $_->parent()->{coindex}; my $a = $p>0 ? $_->afun() : 'XXX'; $p.':'.$a} (@conodes));
                log_info($signature);
                print($signature, "\t", $node->get_address(), "\n");
                $counter->{$signature}++;
            }
        }
    }
}

override 'process_end' => sub {
    my $self = shift;
    my $counter = $self->_counter();
    my @ns = sort {$a cmp $b} (keys(%{$counter}));
    foreach my $n (@ns)
    {
        print("# Coord $n\t$counter->{$n}\n");
    }

    super();
};

1;

=over

=item Treex::Block::HamleDT::Harmonize

Common methods for language-dependent blocks that transform trees from the
various styles of the CoNLL treebanks to the style of the Prague Dependency
Treebank (PDT).

The analytical functions (afuns) need to be guessed from C<conll/deprel> and
other sources of information. The tree structure must be transformed at places
(e.g. there are various styles of capturing coordination).

Morphological tags should be decoded into Interset. Then the C<tag> attribute
should be set to the PDT 15-character positional tag matching the Interset
features.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
