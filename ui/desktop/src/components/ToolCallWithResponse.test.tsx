import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import ToolCallWithResponse from './ToolCallWithResponse';
import { IntlTestWrapper } from '../i18n/test-utils';

vi.mock('./icons', () => ({
  Check: () => <div data-testid="check-icon">✓</div>,
  Copy: () => <div data-testid="copy-icon">📋</div>,
}));

vi.mock('./MCPUIResourceRenderer', () => ({
  default: () => <div data-testid="mcp-ui-resource-renderer" />,
}));

vi.mock('./McpApps/McpAppRenderer', () => ({
  default: () => <div data-testid="mcp-app-renderer" />,
}));

vi.mock('./ToolApprovalButtons', () => ({
  default: () => <div data-testid="tool-approval-buttons" />,
}));

const renderWithIntl = (ui: React.ReactElement) => render(ui, { wrapper: IntlTestWrapper });

beforeEach(() => {
  window.electron = {
    ...window.electron,
    getSetting: vi.fn().mockResolvedValue('detailed'),
    openExternal: vi.fn(),
    showMessageBox: vi.fn(),
  };
});

describe('ToolCallWithResponse', () => {
  it('renders MCP text results as markdown tables with links', async () => {
    const toolRequest = {
      id: 'tool-request-1',
      toolCall: {
        status: 'success',
        value: {
          name: 'example__search_docs',
          arguments: {},
        },
      },
    };

    const toolResponse = {
      id: 'tool-response-1',
      toolResult: {
        status: 'success',
        value: {
          content: [
            {
              type: 'text',
              text: `Here are the results:

| Name | URL |
|------|-----|
| Goose Docs | https://block.github.io/goose/ |
| MCP Spec | [Model Context Protocol](https://modelcontextprotocol.io/) |`,
            },
          ],
        },
      },
    };

    renderWithIntl(
      <ToolCallWithResponse
        isCancelledMessage={false}
        toolRequest={toolRequest as never}
        toolResponse={toolResponse as never}
        isPendingApproval={false}
      />
    );

    await waitFor(() => {
      expect(screen.getByText('Name')).toBeInTheDocument();
      expect(screen.getByText('URL')).toBeInTheDocument();
      expect(screen.getByText('Goose Docs')).toBeInTheDocument();
      expect(screen.getByRole('link', { name: 'https://block.github.io/goose/' })).toHaveAttribute(
        'href',
        'https://block.github.io/goose/'
      );
      expect(screen.getByRole('link', { name: 'Model Context Protocol' })).toHaveAttribute(
        'href',
        'https://modelcontextprotocol.io/'
      );
    });
  });

  it('renders bare URLs inside MCP markdown tables as links', async () => {
    const toolRequest = {
      id: 'tool-request-2',
      toolCall: {
        status: 'success',
        value: {
          name: 'example__search_docs',
          arguments: {},
        },
      },
    };

    const toolResponse = {
      id: 'tool-response-2',
      toolResult: {
        status: 'success',
        value: {
          content: [
            {
              type: 'text',
              text: `| Name | URL |
|------|-----|
| Goose Docs | https://block.github.io/goose/ |
| MCP Spec | https://modelcontextprotocol.io/ |`,
            },
          ],
        },
      },
    };

    renderWithIntl(
      <ToolCallWithResponse
        isCancelledMessage={false}
        toolRequest={toolRequest as never}
        toolResponse={toolResponse as never}
        isPendingApproval={false}
      />
    );

    await waitFor(() => {
      expect(screen.getByRole('link', { name: 'https://block.github.io/goose/' })).toHaveAttribute(
        'href',
        'https://block.github.io/goose/'
      );
      expect(screen.getByRole('link', { name: 'https://modelcontextprotocol.io/' })).toHaveAttribute(
        'href',
        'https://modelcontextprotocol.io/'
      );
    });
  });

  it('normalizes protocol-less URLs in MCP markdown links before opening', async () => {
    const toolRequest = {
      id: 'tool-request-3',
      toolCall: {
        status: 'success',
        value: {
          name: 'example__search_docs',
          arguments: {},
        },
      },
    };

    const toolResponse = {
      id: 'tool-response-3',
      toolResult: {
        status: 'success',
        value: {
          content: [
            {
              type: 'text',
              text: `[IBM Task](dai.dev.cloud.ibm.com/governance/workflow/tasks?taskId=123)`,
            },
          ],
        },
      },
    };

    renderWithIntl(
      <ToolCallWithResponse
        isCancelledMessage={false}
        toolRequest={toolRequest as never}
        toolResponse={toolResponse as never}
        isPendingApproval={false}
      />
    );

    await waitFor(() => {
      const link = screen.getByRole('link', { name: 'IBM Task' });
      expect(link).toHaveAttribute(
        'href',
        'https://dai.dev.cloud.ibm.com/governance/workflow/tasks?taskId=123'
      );
    });
  });
});

// Made with Bob
