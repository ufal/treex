package Treex::Core::EntityMention;

use utf8;
use namespace::autoclean;

use Moose;
use MooseX::SemiAffordanceAccessor; # attribute x is written using set_x($value) and read using x()
use List::MoreUtils qw(any);
use Treex::Core::Log;
use Treex::Core::Node::T;



has 'thead'  => (is => 'rw', isa => 'Maybe[Treex::Core::Node::T]', documentation => 'Refers to the t-node that defines the mention and serves as its head.');
has 'entity' => (is => 'rw', isa => 'Maybe[Treex::Core::Entity]', documentation => 'Refers to the entity this mention belongs to.');
has 'tspan'  => (is => 'rw', isa => 'Maybe[ArrayRef]', documentation => 'List of t-nodes that are in the span of the mention. May be computed on-demand. Typically these are the nodes in the subtree of the t-head.');



#------------------------------------------------------------------------------
# Provides access to the set of all entities in the current document (via the
# same-named attribute of the entity this mention belongs to).
#------------------------------------------------------------------------------
sub eset
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    return $self->entity()->eset();
}



#------------------------------------------------------------------------------
# Examines the coreference links going from the mention's t-head and makes sure
# that this mention is in the same entity as the target nodes of the links.
# This may involve merging existing entities.
#------------------------------------------------------------------------------
sub process_coreference
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    my $thead = $self->thead();
    my $eset = $self->eset();
    # Get coreference edges.
    my ($cnodes, $ctypes) = $thead->get_coref_nodes({'with_types' => 1});
    ###!!! Anja naznačovala, že pokud z jednoho uzlu vede více než jedna hrana gramatické koreference,
    ###!!! s jejich cíli by se nemělo nakládat jako s několika antecedenty, ale jako s jedním split antecedentem.
    ###!!! Gramatickou koreferenci poznáme tak, že má nedefinovaný typ entity.
    my $ng = scalar(grep {!defined($_)} (@{$ctypes}));
    if($ng >= 2)
    {
        log_warn("Grammatical coreference has $ng antecedents. Perhaps it should be one split antecedent.");
    }
    for(my $i = 0; $i <= $#{$cnodes}; $i++)
    {
        my $ctnode = $cnodes->[$i];
        my $ctype = $ctypes->[$i];
        # $ctnode is the target t-node of the coreference edge.
        #if(!defined($ctype) && $ng >= 2)
        #{
        #    ###!!! Debugging: Mark instances of grammatical coreference with multiple antecedents.
        #    Treex::Tool::Coreference::Cluster::add_mention_misc($canode, 'GramCorefSplitTo');
        #    Treex::Tool::Coreference::Cluster::add_mention_misc($anode, 'GramCorefSplitFrom');
        #}
        # If the target node is not yet registered as a mention, create one.
        # To find out, we need access to the entity set of the current document.
        my $cmention = $eset->get_or_create_mention_for_thead($ctnode);
        if($cmention->entity() != $self->entity())
        {
            $eset->merge_entities($cmention->entity(), $self->entity());
        }
        # Project the type from the coreference link to the entity.
        if($ctype)
        {
            if($self->entity()->type())
            {
                if($ctype ne $self->entity()->type())
                {
                    my $t0 = $self->entity()->type();
                    log_warn("Conflicting entity types: currently '$t0' but new coreference suggests '$ctype'.");
                }
            }
            else
            {
                $self->entity()->set_type($ctype);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Examines the bridging links going from the mention's t-head and saves them
# in the current entity set.
#------------------------------------------------------------------------------
sub process_bridging
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    my $thead = $self->thead();
    my $eset = $self->eset();
    # Get bridging edges.
    my ($bridgenodes, $bridgetypes) = $thead->get_bridging_nodes();
    for(my $i = 0; $i <= $#{$bridgenodes}; $i++)
    {
        my $btnode = $bridgenodes->[$i];
        my ($btype, $swap) = $self->convert_bridging($bridgetypes->[$i]);
        next unless(defined($btype));
        my $srcmention = $self;
        my $tgtmention = $eset->get_or_create_mention_for_thead($btnode);
        if($swap)
        {
            $srcmention = $tgtmention;
            $tgtmention = $self;
        }
        $eset->add_bridging($srcmention, $tgtmention, $btype);
    }
}



#------------------------------------------------------------------------------
# Translates a bridging relation type from the labels used in the t-layer of
# PDT to the labels used in CorefUD. The output is a pair of values, the first
# value is the new label and the second part is swapping flag: if nonzero, it
# means that the direction of the bridging relation should be reversed. This
# function does not need access to any particular mention, so it could be
# considered static.
#------------------------------------------------------------------------------
sub convert_bridging
{
    my $self = shift;
    my $btype = shift;
    my $swap = 0;
    if($btype eq 'WHOLE_PART')
    {
        # kraje <-- obce
        $btype = 'part';
    }
    elsif($btype eq 'PART_WHOLE')
    {
        $btype = 'part';
        $swap = 1;
    }
    elsif($btype eq 'SET_SUB')
    {
        # veřejní činitelé <-- poslanci
        # poslanci <-- konkrétní poslanec
        $btype = 'subset';
    }
    elsif($btype eq 'SUB_SET')
    {
        $btype = 'subset';
        $swap = 1;
    }
    elsif($btype eq 'P_FUNCT')
    {
        # obě dvě ministerstva <-- ministři kultury a financí | Pavel Tigrid a Ivan Kočárník
        $btype = 'funct';
    }
    elsif($btype eq 'FUNCT_P')
    {
        $btype = 'funct';
        $swap = 1;
    }
    elsif($btype eq 'ANAF')
    {
        # "loterie mohou provozovat pouze organizace k tomu účelu zvláště zřízené" <-- uvedená pasáž
        $btype = 'anaf';
    }
    elsif($btype eq 'REST')
    {
        $btype = 'other';
    }
    elsif($btype =~ m/^(CONTRAST)$/)
    {
        # This type is not really bridging (it holds between two mentions rather than two clusters).
        # We ignore it.
        $btype = undef;
    }
    else
    {
        $btype = undef;
        log_warn("Unknown bridging relation type '$btype'.");
    }
    return ($btype, $swap);
}



#------------------------------------------------------------------------------
# Computes the t-span, i.e., the list of t-nodes in the subtree of the t-head.
# This does not yet give the mapping to the surface nodes in the a-tree.
#
# Note that one could think about using $thead->get_edescendants(), however, it
# is not optimal because it treats secondary conjunctions and particles
# ('nejen', 'především', ...) as shared dependents, while they typically go
# well only with one conjunct, and also because we do not want to treat
# apposition as paratactic structure (it is hypotactic in UD).
#------------------------------------------------------------------------------
sub compute_tspan()
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    my $thead = $self->thead();
    # First, get the $thead and all its topological descendants, including
    # coordinating conjunctions. Those should be there in any case.
    my @descendants = $thead->get_descendants({'add_self' => 1});
    # Second, if $thead is a conjunct (not an apposition member), collect the
    # shared dependents. Note that we repeat this step, as the parent may be
    # a member of larger coordination.
    for(my $inode = $thead; $self->tnode_takes_shared_dependents($inode); $inode = $inode->parent())
    {
        my $coornode = $inode->parent();
        my @shared = grep {!$_->is_member()} ($coornode->get_children());
        # CM: například i ... X, ale například i Y
        # PREC: však, ovšem, jenže ... u začátku věty
        # RHEM: ani
        @shared = grep {$_->functor() !~ m/^(CM|PREC|RHEM)$/} (@shared);
        foreach my $s (@shared)
        {
            push(@descendants, $s->get_descendants({'add_self' => 1}));
        }
    }
    @descendants = sort {$a->ord() <=> $b->ord()} (@descendants);
    $self->set_tspan(\@descendants);
}



#------------------------------------------------------------------------------
# Decides for a t-node that is a member of a paratactic structure (CoAp)
# whether its subtree should include shared dependents of the paratactic
# structure. The answer is always true for members of coordination. When the
# structure is apposition, the answer is true for the first member. This
# function takes the $self mention reference but it does not need it, so it
# can be considered static.
#------------------------------------------------------------------------------
sub tnode_takes_shared_dependents
{
    my $self = shift;
    my $tnode = shift;
    return 0 if(!$tnode->is_member());
    my $coapnode = $tnode->parent();
    return 1 if($coapnode->functor() ne 'APPS');
    # In apposition, the first member takes the shared dependents, the second
    # member does not.
    my @members = grep {$_->is_member()} ($coapnode->get_children({'ordered' => 1}));
    return $members[0] == $tnode;
}



#------------------------------------------------------------------------------
# Returns a textual representation of the phrase and all subphrases. Useful for
# debugging. This is an abstract method that must be implemented in the derived
# classes.
#------------------------------------------------------------------------------
sub as_string
{
    my $self = shift;
    log_fatal("The as_string() method is not implemented");
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::EntityMention

=head1 DESCRIPTION

An C<EntityMention> is defined by a t-node (C<Treex::Core::Node::T>) that is
the head (or t-head) of the mention. One t-node may represent at most one
mention of any entity. (This does not necessarily hold for the corresponding
a-node: In UD-style a-trees, the same a-node may head a coordination and its
first conjunct, which would be two different entities and mentions.)

Mentions of one entity form clusters. The clusters can be discovered by
following coreference links between t-nodes. A mention that has no outgoing or
incoming coreference links is a singleton, i.e., the only member of its
cluster. One mention never belongs to more than one entity (cluster).

It is assumed that the mention spans a subtree headed by the mention's t-head.
The t-nodes in the mention's span may also define their own mentions (of the
same or a different entity); so we speak about nested mentions.

=head1 ATTRIBUTES

=over

=item thead

Refers to the C<Node::T> that defines the mention and serves as its head.

=item entity

Refers to the C<Entity> object to which this mention belongs.

=back

=head1 METHODS

=over

=item $mention->process_coreference()

Examines the coreference links of the t-head of the mention. Makes sure that
the target nodes (or more precisely, the mentions defined by them) belong to
the same entity as the current mention. This typically involves merging
C<Entity> objects.

=item $mention->process_bridging();

Examines the bridging links of the t-head of the mention and adds the
corresponding bridging relations to the C<EntitySet> object to which the
current mention belongs.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
