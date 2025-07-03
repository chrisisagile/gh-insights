import { GitHubAnalystAgent } from '../src/agents/github-analyst-agent.js';
import { config } from 'dotenv';

// Load environment variables
config();

async function runExample() {
  console.log('🔍 Running GitHub Insights Example Analysis\n');

  // Check for required environment variables
  if (!process.env.GITHUB_TOKEN || !process.env.OPENAI_API_KEY) {
    console.error('❌ Missing required environment variables!');
    console.error('Please set GITHUB_TOKEN and OPENAI_API_KEY in your .env file');
    process.exit(1);
  }

  try {
    // Create the analysis agent
    const agent = new GitHubAnalystAgent(
      process.env.GITHUB_TOKEN,
      process.env.OPENAI_API_KEY,
      process.env.OPENAI_MODEL || 'gpt-4-turbo-preview'
    );

    // Example 1: Analyze test coverage for recent PRs
    console.log('📊 Example 1: Analyzing test coverage...\n');
    await agent.analyze({
      reviewFocus: 'test coverage, testing patterns, test quality',
      prSelection: 'last 5',
      outputDir: './insights/example1'
    });

    // Example 2: Architecture review of largest PRs
    console.log('\n🏗️  Example 2: Architecture review...\n');
    await agent.analyze({
      reviewFocus: 'architecture, code organization, design patterns',
      prSelection: 'largest 3',
      outputDir: './insights/example2'
    });

    // Example 3: Security audit of recent changes
    console.log('\n🔒 Example 3: Security audit...\n');
    await agent.analyze({
      reviewFocus: 'security, authentication, secrets management, vulnerabilities',
      prSelection: 'last-week',
      outputDir: './insights/example3'
    });

    console.log('\n✅ All examples completed successfully!');
    console.log('Check the ./insights directory for results.');

  } catch (error) {
    console.error('❌ Error running examples:', error);
    process.exit(1);
  }
}

// Run the examples
runExample();