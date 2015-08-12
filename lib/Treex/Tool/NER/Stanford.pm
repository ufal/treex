package Treex::Tool::NER::Stanford;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Treex::Tool::ProcessUtils;
use File::Temp qw(tempdir);
with 'Treex::Tool::NER::Role';

# Path to the model data file
has model => ( is => 'ro', isa => 'Str', default => 'data/models/stanford_named_ent_recognizer/stanford-ner-2008-05-07/classifiers/ner-eng-ie.crf-3-all2008.ser.gz' );

# Memory allowed to the java process
has memory => ( is => 'ro', isa => 'Str', default => '610m' );

has debug => ( is => 'rw', isa => 'Bool', default => 0, documentation => 'print extra debug info, do not delete temporary files');

# Stanford NER main JAR, path within share
has jar => ( is => 'ro', isa => 'Str', default => 'data/models/stanford_named_ent_recognizer/stanford-ner-2008-05-07/stanford-ner-hacked-STDIN.jar');

# PIDs of java processes
my @all_javas;

sub BUILD {
    my ( $self, $arg_ref ) = @_;

    # New Stanford NER needs Java 1.8 or higher
    # Unfortunately, java itself dies with no clear message if used with older version.
    if ($self->jar =~ /2015-01-30/){
        my $three_lines = `java -version 2>&1`;
        my ($java_version) = ($three_lines =~ /java version "(\d+.\d+)/);
        log_fatal "Could not detect Java version, make sure it is installed.\njava -version\n$three_lines" if !defined $java_version;
        log_fatal "Java 1.8 or higher is required to run Stanford NER\n".
                   $self->jar . "\nbut your version is $java_version\n$three_lines"
            if $java_version < 1.8;
    }
    
    # download the jar and the model if necessary
    my $jar   = Treex::Core::Resource::require_file_from_share($self->jar); 
    my $model = Treex::Core::Resource::require_file_from_share($self->model); 
    my $out_redirect = $self->debug ? '' : '2>/dev/null';
    # newer versions of Stanford NER
    my $in_redirect = $self->jar =~ /2008-05-07/ ? '-textFile STDIN' : '-readStdin';
    my $model_memory = $self->memory;

    my $tempdir = tempdir( DIR => Treex::Core::Config->tmp_dir() , CLEANUP => !$self->debug );
    print "Tempdir for Java Stanford NER: $tempdir; delete yourself" if $self->debug;

    # Stanford NER has to run within a blank directory.
    # It creates tempfiles that may clash with your directory contents.
    my $command = "cd $tempdir && java -Xmx$model_memory"
        . " -cp $jar edu.stanford.nlp.ie.crf.CRFClassifier "
        . "-loadClassifier $model $in_redirect $out_redirect";

    print STDERR "QQQQ $command QQQQ\n" if $self->debug;

    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);

    $self->{reader} = $reader;
    $self->{writer} = $writer;
    $self->{pid}    = $pid;

    bless $self;
    push @all_javas, $self;

    return $self;
}

# ----------------- the main method -----------------------


sub find_entities {
    my ( $self, $forms_rf ) = @_;
    
    my $num_toks = scalar(@$forms_rf);
    my $types_rf = $self->tag_forms($forms_rf);
    
    my (@entities, $ent);
    for my $i (0 .. $num_toks){
        my $type = $types_rf->[$i] || 'O';
        if ($type eq 'O' or $type eq 'NA'){
            if ($ent){
                $ent->{end} = $i-1;
                push @entities, $ent;
                $ent = 0;
            }
        } else {
            if ($ent){
                if ($ent->{type} ne $type){
                    $ent->{end} = $i-1;
                    push @entities, $ent;
                    $ent = {start=>$i, type=>$type};
                }
            } else {
                $ent = {start=>$i, type=>$type};
            }
        }
    }
    return \@entities;
}
    
sub tag_forms {
    my ( $self, $forms_rf ) = @_;

    log_fatal 'Argument must be an array reference' if ref($forms_rf) ne 'ARRAY';
    log_fatal 'Empty or white-space-only wordform' if any {/^\s+$/} @$forms_rf;

    my $writer = $self->{writer};
    my $reader = $self->{reader};
    my $input = join ' ', @$forms_rf;
    
    # older versions of Stanford NER crash on punctuation-only sentences. Let's skip them.
    return if $input =~ /^[[:punct:]\s]*$/;
    
    print {$writer} "$input\n";
    warn "INPUT FOR JAVA: $input\n" if $self->debug;

    my $ret = <$reader>;
    log_fatal "Treex::Tool::NER::Stanford died, got no output for input '$input'" if !defined $ret;
    chomp $ret;
    my @types = split /\s+/, $ret;
    if ( @types == @$forms_rf ) {
        @types = map { s{.*/}{}; $_ } @types;
        return ( \@types );
    }
    else {
        return [ map { $ret =~ m|\Q$_\E/(\w*)| ? $1 : 'NA' } @{$forms_rf} ];
    }
}

# ----------------- cleaning up ------------------

END {
    foreach my $java (@all_javas) {
        close( $java->{writer} );
        close( $java->{reader} );
        Treex::Tool::ProcessUtils::safewaitpid( $java->{pid} );
        log_info("Java NER PID $java->{pid} exited.");
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::NER::Stanford - wrapper for Stanford named entity recognizer

=head1 SYNOPSIS

 use Treex::Tool::NER::Stanford;
 my $ner = Treex::Tool::NER::Stanford->new(
    model => 'data/models/stanford_named_ent_recognizer/en/ner-eng-ie.crf-3-all2008.ser.gz',
 );

 my @tokens = qw(I study computer science . I grew up in New Jersey .);
 my $entities_rf = $ner->find_entities(\@tokens);
 for my $entity (@$entities_rf) {
     my $entity_string = join ' ', @tokens[$entity->{start} .. $entity->{end}];
     print "type=$entity->{type} entity=$entity_string\n";
 }
 
 # Alternative interface
 my $types_rf = $ner->tag_forms(\@tokens);
 for my $i (0..$#tokens) {
     print $i + 1 . ": wordform=$tokens[$i]\ttype=$types_rf->[$i]\n";
 }
 # Types are
 # PERSON, ORGANIZATION, LOCATION, O

=head1 DESCRIPTION

Perl wrapper for (modified) Stanford NER Version 1.5 2008-05-07
When being used, it executes a Java Server and loads the NER model.

=head1 PARAMETERS

=over

=item model

Path to the model file within Treex share.

Possible models (for English) are

ner-eng-ie.crf-3-all2008-distsim.ser.gz (default - big, loading time < 26s)

ner-eng-ie.crf-3-all2008.ser.gz (small, 1.5% worse, loading time < 4s)

=back

=head1 METHODS

=over

=item $entities_rf = $ner->find_entities(\@tokens);

Input: @tokens is an array of word forms (tokenized sentence).
Output: $entities_rf is a reference to an array of the recognized named entities.
Each named entity is a hash ref with keys: C<type, start, end>.
C<type> is the type of the named entity.
C<start> and <end> are (zero-based) indices to the input C<@tokens>
indicating which tokens form the given named entity.

=item my $types_rf = $ner->tag_forms(\@tokens);

Reference to an array of word forms is given as argument.
Reference to an array of types is returned.

=back

=head1 SEE ALSO

L<http://nlp.stanford.edu/software/CRF-NER.shtml>

Jenny Rose Finkel, Trond Grenager, and Christopher Manning. 2005. Incorporating
Non-local Information into Information Extraction Systems by Gibbs Sampling.
Proceedings of the 43nd Annual Meeting of the Association for Computational
Linguistics (ACL 2005), pp. 363-370.
http://nlp.stanford.edu/~manning/papers/gibbscrf3.pdf

The software provided here is similar to the baseline local+Viterbi model in
that paper, but adds new distributional similarity based features (in the
-distSim classifiers).

=head1 AUTHOR

Václav Novák

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
