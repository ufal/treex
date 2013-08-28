package Treex::Block::Test::A::CoordStyle;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

has style => (
    is            => 'rw',
    isa           => 'Str',
    default       => 'fPhRsHcHpB',
    documentation => 'coord style - encoded in a single string as in HamleDT papers (e.g. fPhRsHcHpB)',
);

has stylefrompath => (
    is => 'rw',
    isa => 'Bool',
);

has fix => (
    is => 'ro',
    documentation => 'fix detected errors (even if the change might be only formal)'
);

sub process_document {
    my ($self,$document) = @_;
    if ($self->stylefrompath) {
        if ( $document->full_filename() =~ /(f[PMS]([a-z][A-Z])+)/) {
#            print "Style detected from filename: $1\n";
            $self->set_style($1);
        }
        elsif ( $document->full_filename() =~ /001_pdtstyle/) {
            $self->set_style('fPhRsHcHpB');
        }
        else {
            log_fatal ("Coordination style code not found in the file name");
        }
    }

    Treex::Core::Block::process_document(@_); # TODO: lepsi by bylo volat metodu primeho predka
}


sub process_atree {
    my ($self, $aroot) = @_;

    if ($self->style =~ /fP/) {
        $self->_test_prague($aroot);
    }
    elsif ($self->style =~ /fS/) {
        $self->_test_stanford($aroot);
    }
    elsif ($self->style =~ /fM/) {
        $self->_test_moscow($aroot);
    }
    else {
        log_fatal('Unrecognized coordination style code: '.$self->style);
    }

#    if ($anode->is_coap_root and not first {$_->is_member} $anode->get_children) {
#        $self->complain($anode);
#    }
}

sub _test_prague {
    my ($self, $aroot) = @_;

    foreach my $anode ($aroot->get_descendants) {

        if ($anode->is_member and not $anode->get_parent->afun eq 'Coord') {
            $self->_my_complain($anode, 'Conjuncts (is_member=1) can appear only below afun=Coord');
            # TODO: co vlastne delame s is_member v apozicich? Asi by bylo lepsi je vynulovat, at se nepletou do koordinaci!
        }

        if ($anode->is_shared_modifier and not $anode->get_parent->afun eq 'Coord') {
            $self->_my_complain($anode, 'Shared modifiers (is_shared_modifier=1) can appear only below afun=Coord');
        }

        if ($anode->afun eq 'Coord' and not first {$_->is_member} $anode->get_children) {
            $self->_my_complain($anode, 'There should be at least one conjunct below each afun=Coord');
        }

        if ($anode->is_member and $anode->is_shared_modifier) {
            $self->_my_complain($anode, 'A node cannot be a conjunct and a share modifier at the same time');
        }

        if ($anode->afun eq 'Coord') {
            my @conjuncts = grep {$_->is_member} $anode->get_children({ordered=>1});
            foreach my $i (0..$#conjuncts-1) {
                if ( $conjuncts[$i]->ord + 1 == $conjuncts[$i+1]->ord ) {
                    $self->_my_complain($conjuncts[$i], 'Conjuncts should never be immediately adjacent');
                    # TODO: vyloucit jazyky, ve kterych je vyhazena interpunkce anebo se v nich tahle vec muze stat z jinych duvodu
                }
            }
        }
    }
} # end of _test_prague

sub _test_moscow {
    my ($self, $aroot) = @_;

    my %is_coord_root; # coordination roots (the highest conjuncts) are not marked as coordination members, so let's precompute them
    foreach my $anode ($aroot->get_descendants) {
        if ($anode->is_member and not ($anode->get_parent->is_member or $anode->get_parent->wild->{is_coord_conjunction})) {
            $is_coord_root{$anode->get_parent} = 1;
        }
    }
    # terminology: conjunct <=> is_member or is_coord_root

    foreach my $anode ($aroot->get_descendants) {

        if ($anode->wild->{is_coord_conjunction} and not ($is_coord_root{$anode->get_parent} or $anode->get_parent->is_member)) {
            $self->_my_complain($anode,'Each conjunction should be placed below a conjunct');
        }

        if ($anode->is_shared_modifier and not ($is_coord_root{$anode->get_parent} or $anode->get_parent->is_member)) {
            $self->_my_complain($anode,'Each shared modifier must be placed below a conjunct');
        }

        if ($anode->wild->{is_coord_conjunction} and $self->style =~ /c[PF]/ and first {$_->is_member} $anode->get_children) {
            $self->_my_complain($anode,'There should be no is_member=1 below a conjunction');
        }
    }
} # end of _test_moscow

sub _test_stanford {
    my ($self,$aroot) = @_;

    my %is_coord_root; # again, coordination roots (the highest conjuncts) are not marked as coordination members, so let's precompute them
    foreach my $anode ($aroot->get_descendants) {
        if ($anode->is_member) {
            $is_coord_root{$anode->get_parent} = 1;
        }
    }

    foreach my $anode ($aroot->get_descendants) {

        if ($anode->wild->{is_coord_conjunction} and not ($anode->get_parent->is_member or $is_coord_root{$anode->get_parent})) {
            $self->_my_complain($anode,'Each conjunction must be placed below a conjunct');
        }

        if ($is_coord_root{$anode}) {
            my @coord_participants = grep {$_->is_member or $_->wild->{is_coord_conjunction}} $anode->get_children;
            my @left_participants = grep {$_->precedes($anode)} @coord_participants;
            my @right_participants = grep {$anode->precedes($_)} @coord_participants;
            if (@left_participants and @right_participants) {
                $self->_my_complain($anode,'Participants of CS must be placed only in one direction w.r.t. the main conjunct, not both.');
            }
        }

        if ($anode->wild->{is_coord_conjunction} and $anode->get_parent->is_root) {
            $self->_my_complain($anode,'Conjunctions cannot be placed directly below the technical root');
        }

        if ($anode->is_member and $anode->get_parent->is_root) {
            $self->_my_complain($anode,'is_member=1 cannot be placed directly below the technical root');
        }

        if ($anode->wild->{is_coord_conjunction} and first {$_->is_member or $is_coord_root{$_}} $anode->get_children) {
            $self->_my_complain($anode,'Conjunction cannot have other CS participants among its children');
        }
    }
} # end of _test_stanford



sub _my_complain {
    my ( $self, $anode, $message ) = @_;
    $self->complain( $anode, $message.' in '.$self->style. "\tNode '".$anode->form."' in '".$anode->get_zone->sentence."'" );
}


1;

=over

=item Treex::Block::Test::A::CoordStyle

Checks whether basic assumptions about the given coordination style
hold in a-trees. In other word, the block searches for such combinations of
the following attributes that should never appear:
  afun (only the value 'Coord')
  is_member
  is_shared_modifier
  wild->{is_coord_conjunction}

=back

=cut

# Copyright 2013 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

