package Treex::Tool::Parser::MSTperl::Reader;

use Moose;
use autodie;

has featuresControl => (
    isa => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is => 'ro',
    required => '1',
);

sub read_tsv {
    # (Str $filename)
    my ($self, $filename) = @_;
    
    my @sentences;
    my @nodes;
    my $id = 1;
    open my $file, '<:utf8', $filename;
    print "Reading '$filename'...\n";
    while (<$file>) {
        chomp;
        if (/^$/) {
            my $sentence = Treex::Tool::Parser::MSTperl::Sentence->new(id => $id++, nodes => [@nodes], featuresControl => $self->featuresControl);
            push @sentences, $sentence;
            undef @nodes;

            # only progress and/or debug info
            if (scalar(@sentences) % 50 == 0) {
                print "  " . scalar(@sentences) . " sentences read.\n";
            }
            # END only progress and/or debug info

        } else {
            my @fields = split /\t/;
            my $node = Treex::Tool::Parser::MSTperl::Node->new(fields => [@fields], featuresControl => $self->featuresControl);
            push @nodes, $node;
        }
    }
    close $file;
    print "Done.\n";
    
    return [@sentences];
}

1;
