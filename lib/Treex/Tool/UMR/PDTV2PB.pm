package Treex::Tool::UMR::PDTV2PB;
use warnings;
use strict;

use Moose::Role;
use MooseX::Types::Moose qw( Str FileHandle HashRef );
use Moose::Util::TypeConstraints qw{ class_type };
class_type 'XML::LibXML::Element';
use experimental qw( signatures );

use Treex::Core::Log qw{ log_warn };
use Text::CSV_XS;
use XML::LibXML;
use namespace::clean;

has vallex  => (is => 'ro', isa => Str, init_arg => undef, writer => '_set_vallex');
has csv     => (is => 'ro', isa => Str, init_arg => undef, writer => '_set_csv');
has mapping => (is => 'ro', lazy => 1, isa => HashRef[HashRef[Str]],
                init_arg => undef, builder => '_build_mapping',
                writer => '_set_mapping');
has _csv    => (is => 'ro', lazy => 1, isa => FileHandle,
                init_arg => undef, builder => '_build__csv');
has _vdom   => (is => 'ro', lazy => 1,
                isa => 'XML::LibXML::Document',
                init_arg => undef, builder => '_build__vdom');
has _by_id  => (is => 'ro', lazy => 1,
                isa => HashRef[HashRef['XML::LibXML::Element | Str']],
                init_arg => undef, builder => '_build__by_id');

around BUILD => sub {
    my ($build, $self, $args) = @_;
    if (exists $args->{mapping}) {
        $self->_set_mapping($self->_parse_mapping($args->{mapping}));
    } else {
        $self->_set_vallex($args->{vallex});
        $self->_set_csv($args->{csv});
    }
    $self->$build($args);
};

sub _build__vdom($self) {
    'XML::LibXML'->load_xml(location => $self->vallex)
}

sub _build__csv($self) {
    open my $c, '<:encoding(UTF-8)', $self->csv or die "Can't open CSV: $!";
    return $c
}

sub _build__by_id($self) {
    my %by_id;
    for my $frame ($self->_vdom->findnodes(
        '/valency_lexicon/body/word/valency_frames/frame')
    ) {
        $by_id{ $frame->{id} } = {
            frame => $frame,
            word  => $frame->findvalue('../../self::word/@lemma')};
    }
    return \%by_id
}

sub _build_mapping($self) {
    my %mapping;
    my $csv = 'Text::CSV_XS'->new({binary => 1, auto_diag => 1});
    my $current_id;
    while (my $row = $csv->getline($self->_csv)) {
        next if 1 == $.;

        if ($row->[0]) {
            my ($verb, $frame_id) = $row->[1] =~ /(.*) \((.*)\)/;
            ($self->_by_id->{$frame_id}{word} // "") eq $verb
                or log_warn("$frame_id: $verb != "
                            . ($self->_by_id->{$frame_id}{word} // '-'));
            $current_id = $frame_id;
            my $umr_id = ($row->[0] =~ /^"(.*)"$/)[0];
            log_warn("Already exists $current_id!")
                if exists $mapping{$current_id}
                && $mapping{$current_id}{umr_id} ne $umr_id;
            $mapping{$current_id}{umr_id} = $umr_id;

        } elsif ($row->[3]) {
            my $functor = $row->[1] =~ s/:.*//r;
            log_warn("Ambiguous mapping $mapping{$current_id}{umr_id}"
                     . " $current_id $functor:"
                     . " $row->[3]/$mapping{$current_id}{$functor}!")
                if exists $mapping{$current_id}{$functor}
                && $mapping{$current_id}{$functor} ne $row->[3];
            $mapping{$current_id}{$functor} = $row->[3];
        }
    }
    close $self->_csv;
    return \%mapping
}

sub _parse_mapping($self, $file) {
    my %mapping;
    my @pairs;
    open my $in, '<', $file or die $!;
    my ($umr_id);
    while (my $line = <$in>) {
        if ($line =~ /^ : id: ([-\w]+)/) {
            $umr_id = $1;

        } elsif ($line =~ /^ \+ (.*)/) {
            push @pairs, split /, /, $1;

        } elsif ($line =~ /^\s*-Vallex1_id: (.*)/) {
            my @frames = split /; /, $1;
            for my $frame (@frames) {
                $frame =~ s/^v#//;
                $mapping{$frame}{umr_id} = $umr_id;
                log_warn("Already exists $umr_id")
                    if exists $mapping{$frame}
                    && $mapping{$frame}{umr_id} ne $umr_id;

                for my $pair (@pairs) {
                    my ($functor, $relation) = $pair =~ /(\w+) \[(\w+)\]/
                        or next;

                    next if 'NA' eq $relation;

                    log_warn("Ambiguous mapping $frame $functor:"
                             . " $relation/$mapping{$frame}{$functor}")
                        if exists $mapping{$frame}{$functor}
                        && $mapping{$frame}{$functor} ne $relation;
                    $mapping{$frame}{$functor} = $relation;
                }
            }
            @pairs = ();
        }

    }
    return \%mapping
}

1
